# Start-Check UX-Konzept ("Dein Startpunkt")

UX-Fix-Dokument `ONBOARDING_MATCHING_AND_UX_FIX.md`, Problem 3. Ersetzt die
lineare Schritt-für-Schritt-Fassung des Start-Checks (Sicherheit → Push →
Beine → Ziehen → Rumpf → Ausdauer → Intensität → Ergebnis) durch eine
Hub-and-Spoke-Navigation: eine Übersicht mit frei wählbarer Reihenfolge statt
einer erzwungenen Kette. Bestehende Daten- und Zustandsmodelle
(`BaselineAssessment`, `BaselineAssessmentEvaluator`, `PausableTimerState`)
werden unverändert weiterverwendet — nur Präsentation und Navigation ändern
sich.

Kein Design-/SwiftUI-UI-Skill für freie Konzept-Generierung aus einem reinen
Text-Briefing in dieser Umgebung verfügbar (die installierte `swiftui-pro`-
Skill ist eine Code-Review-Checkliste, kein Flow-Designer) — dieses Dokument
ist deshalb die in der Vorgabe genannte Alternative.

## 1. Prinzip: Einladung statt Prüfung

- Titel: **"Dein Startpunkt"**
- Subtext: **"Optional: Mit 2–3 kurzen Checks machen wir deinen Einstieg
  passender. Es gibt kein Bestehen oder Durchfallen."**
- Drei gleichwertige Wege, keiner optisch bevorzugt außer dem ersten (als
  Standardempfehlung leicht hervorgehoben, aber alle drei vollwertig):
  1. **"Kurz testen"** → gefühter Weg, siehe §3.
  2. **"Selbst einschätzen"** → Selbsteinschätzung für alle Familien, kein
     Belastungstest.
  3. **"Später entscheiden"** → beendet den Schritt ohne Ergebnis, identisch
     zum Bestandsnutzer-Zustand (`baselineAssessment == nil`).
- Nie ein Gate: der Nutzer kann diesen gesamten Onboarding-Schritt jederzeit
  über die normale "Weiter"-Leiste verlassen, auch mitten in der Übersicht.

Erfahrene Nutzer (siehe §6) sehen diese drei Wege gar nicht — nur einen
kompakten Link.

## 2. User Flow (Übersicht)

```
Onboarding-Schritt "Start-Check"
  │
  ├─ "Kurz testen"       ──┐
  ├─ "Selbst einschätzen" ─┼─→ Sheet: BaselineCheckFlowView
  └─ "Später entscheiden" ─┘        (siehe unten; bei "Später" kein Sheet)

BaselineCheckFlowView (ein NavigationStack, EIN Sheet):
  │
  ├─ [nur bei "Kurz testen"] Sicherheits-Karte (§4)
  │     "Ja, los geht's"      → weiter zur Übersicht, Tests erlaubt
  │     "Lieber ohne Test"    → weiter zur Übersicht, NUR Selbsteinschätzung
  │
  ├─ Übersicht (Hub, §3)
  │     Karte "Oberkörper"  ──→ Familien-Mini-Flow (Push) ──→ zurück zur Übersicht
  │     Karte "Beine"       ──→ Familien-Mini-Flow (Beine) ──→ zurück zur Übersicht
  │     Karte "Ausdauer"*   ──→ Familien-Mini-Flow (Cardio) ──→ zurück zur Übersicht
  │     "Optional erweitern" (eingeklappt)
  │        Karte "Ziehen"   ──→ Familien-Mini-Flow (Pull) ──→ zurück zur Übersicht
  │        Karte "Rumpf"    ──→ Familien-Mini-Flow (Core) ──→ zurück zur Übersicht
  │     [primäre Aktion, immer aktiv] "Weiter" ──┐
  │                                               │
  ├─ Wie anstrengend darf Woche 1 sein? ←─────────┘
  │     (3 Optionen, Default "Angenehm fordernd")
  │     "Weiter"
  │
  └─ Ergebnis (§5)
        "Plan ansehen" → Sheet schließt, Onboarding geht zum naechsten
        Schritt (Plan-Auswahl) weiter

* Karte "Ausdauer" nur sichtbar, wenn `TrainingGoal == .hybrid` (einzige
  bestehende Achse mit Ausdaueranteil, siehe Audit in `BaselineCheckFlowView`).
```

Jede Familien-Karte kann in beliebiger Reihenfolge angetippt werden oder
unangetastet bleiben (Status bleibt dann "Offen", siehe §3.1) — "Weiter" auf
der Übersicht ist nach dem allerersten Rendern bereits aktiv, nicht erst nach
Bearbeitung aller Karten.

## 3. Übersicht (Hub-Screen)

### 3.1 Karten-Status

Jede Familien-Karte zeigt genau einen von drei Zuständen, farblich und per
Text unterschieden (nie nur über Farbe, siehe §7):

| Status | Bedingung | Icon | Farbe |
|---|---|---|---|
| Offen | Familie weder getestet noch eingeschätzt noch übersprungen | `circle` | `.secondary` |
| Erfasst | Test gespeichert ODER Selbsteinschätzung gewählt | `checkmark.circle.fill` | `.green` |
| Übersprungen | Nutzer hat explizit "Überspringen" gewählt | `minus.circle.fill` | `.secondary` |

### 3.2 Kartenlayout (pro Familie)

Eine Reihe pro Familie, keine Grid-Kacheln (einfacher bei Dynamic Type /
iPhone SE, siehe §8):

```
┌─────────────────────────────────────────────┐
│ [Icon 40x40]  Oberkörper              [●Status] │
│               Liegestütze                  >  │
└─────────────────────────────────────────────┘
```

- Linkes Icon: Bewegungsfamilie (figure.strengthtraining.traditional /
  figure.cooldown / figure.run …), 40×40, konsistent mit anderen
  Icon-Kacheln im Onboarding (Deltiq.Radius.input).
- Titel: Familienname ("Oberkörper" / "Beine" / "Ausdauer" / "Ziehen" /
  "Rumpf"), darunter eine Zeile mit der konkreten Übung ("Liegestütze") in
  `.caption`/`.secondary`.
- Rechts: Status-Icon + Chevron, ganze Zeile ist ein `Button` → NICHT
  `onTapGesture` (VoiceOver/Hit-Target, siehe §7).

### 3.3 "Optional erweitern"

`DisclosureGroup` (Standard-Komponente, kein Custom-Chevron-Dreieck) mit den
Karten "Ziehen" und "Rumpf" — eingeklappt per Default. Label macht explizit,
dass dies KEINE Kernstrecke ist: "Optional erweitern (Ziehen, Rumpf)".

## 4. Sicherheitsgate (unaufdringlich)

Kompakte Karte, KEIN Vollbild-Block, KEIN Warn-Rot als dominante Fläche —
dezente Karte mit einem neutralen Hinweis-Icon:

```
┌─────────────────────────────────────────────┐
│  🩺  Heute beschwerdefrei?                    │
│      Schmerzen, Schwindel oder Brustschmerz    │
│      aktuell? Dann lieber ohne Belastungstest. │
│                                                │
│  [ Ja, los geht's ]   [ Lieber ohne Test ]    │
└─────────────────────────────────────────────┘
```

Nur 2 Antworten (vorige Fassung hatte 3: Ja/Unsicher/Nein — das
zugrundeliegende Datenmodell `SafetyStatus` ist ohnehin binär `.clear`/
`.flagged`, "Unsicher" und "Nein" liefen intern bereits auf dasselbe
Ergebnis. Die neue 2-Options-Frage spiegelt das ehrlich, statt eine
Scheingenauigkeit vorzutäuschen):

- **"Ja, los geht's"** → `safetyStatus = .clear`, Übersicht bietet für jede
  Familie Test + Selbsteinschätzung + Überspringen an.
- **"Lieber ohne Test"** → `safetyStatus = .flagged`, Übersicht bietet NUR
  Selbsteinschätzung + Überspringen an (kein Belastungstest-Button sichtbar);
  dezenter Hinweis "Bei anhaltenden Beschwerden sprich mit einer Ärztin oder
  einem Arzt" erscheint einmalig, nicht wiederholt auf jeder Karte.

Wird nur gezeigt, wenn der Einstieg "Kurz testen" war — bei "Selbst
einschätzen" entfällt sie (kein Belastungstest geplant, siehe §1).

## 5. Ein Test-Screen = eine Aktion

Jede Familien-Karte öffnet zunächst (falls Test erlaubt, siehe §4) eine
Mode-Wahl: **Test machen** / **Selbst einschätzen** / **Überspringen** — als
drei gleich große, vertikal gestapelte Optionen, keine Segmented-Control
(Dynamic-Type-sicherer).

### 5.1 Test-Bildschirm (Beispiel: Push)

1. GIF/Illustration oben (`ExerciseGifView`, bestehend), darunter max. 2
   kurze Cues ("Körper bildet eine gerade Linie", "Ellbogen nicht komplett
   durchdrücken").
2. Varianten-Wahl (Standard/Knie/Erhöht/Noch keine saubere Wiederholung) —
   **vor** jeder Zähl-Interaktion, niemals gleichzeitig mit einem laufenden
   Timer.
3. Eine große Primäraktion. Bei Push (kein Timer): direkt der
   Wiederholungs-Stepper + **"Speichern"** als expliziter Abschluss.
4. Sichtbarer, aber zurückhaltender "Überspringen"-Link unten.

### 5.2 Timer-Bildschirme (Beine, Rumpf)

**Wichtig — Trennung von Timer und Zähleingabe:** solange der Timer läuft
ODER pausiert ist, ist NUR die Zeitanzeige + Start/Pause/Abbrechen sichtbar.
Keine Stepper, keine Zahleneingabe auf demselben Bildschirm-Zustand.

```
Phase "laufend"/"pausiert":        Phase "beendet":
┌─────────────────────┐           ┌─────────────────────┐
│       00:17          │           │  Wie viele saubere   │
│                       │  ───→     │  Wiederholungen?     │
│  [Pause] [Abbrechen]  │           │     [-]  8  [+]       │
└─────────────────────┘           │     [ Speichern ]     │
                                    └─────────────────────┘
```

Erst NACH Timer-Ende (regulär abgelaufen oder manuell "Fertig") erscheint
die Wiederholungsbestätigung mit +/−-Stepper (Default-Wert 0, frei
korrigierbar — "Freitext" bleibt verboten, siehe bestehende Regel) und einem
expliziten **"Speichern"**-Button, der den Wert erst dann in den
Familien-Status "Erfasst" überführt. Plank (Rumpf) folgt demselben Muster,
nur zählt die Zeit hoch statt runter (Deckel 60s) und es gibt keine
Wiederholungen — "Speichern" übernimmt direkt die gehaltene Sekundenzahl.

### 5.3 Pull (Equipment-abhängig)

Unverändert gegenüber der vorigen Fassung: Cable/Machine-Equipment →
Latzug-Test (Gewicht + Wiederholungen + RIR, kein Timer, ein Formular-
Bildschirm mit "Speichern"); sonst Frage nach einer Klimmzugstange → Test
oder (ohne Stange) automatisch nur Selbsteinschätzung/Überspringen, nie eine
unpassende Ersatzübung.

### 5.4 Ausdauer

Kein Test — vier Selbstauskunfts-Optionen, einfacher Single-Select (Tap =
sofort "Erfasst", kein gesondertes "Speichern" nötig, da keine editierbare
Zahl im Spiel ist).

## 6. Ergebnis als Plan-Brücke

Keine Kategorie, kein Score, keine Zahl. Maximal 2 Aussagen:

1. Eine Tendenz-Aussage ohne Note (z. B. "Wir starten mit gut lernbaren
   Varianten." / "Du startest im normalen Tempo." — Ton variiert nach Band,
   Inhalt bleibt nie eine Zahl).
2. Ein Re-Check-Hinweis: "Du kannst in 3–6 Wochen neu prüfen, ob sich etwas
   verändert hat — verglichen nur mit deinem eigenen Start."

Darunter, **eingeklappt** (`DisclosureGroup`, Default zu): "Details zu deinem
Check" — zeigt für Interessierte die einzelnen Familien-Ergebnisse (ohne
Zahlen-Score, nur "Erfasst"/"Übersprungen" + Modus).

Ein klar gekennzeichneter, kleiner Hinweistext (bis Phase 4 verpflichtend):
**"Dein Check wird gespeichert und hilft uns, deine Trainingsvorschläge
zukünftig passender zu machen."** — bewusst KEINE Behauptung einer
sofortigen automatischen Plananpassung (die existiert erst ab Phase 4,
siehe `BaselineAssessmentEvaluator`-Doku).

Primäraktion: **"Plan ansehen"** statt eines neutralen "Fertig" — schließt
das Sheet und führt den Onboarding-Flow zum nächsten (Plan-)Schritt, macht
den Zweck des nächsten Schritts bereits in der Beschriftung klar.

## 7. Accessibility

- Jede Karte/Zeile ein `Button`, nie `onTapGesture` — VoiceOver bekommt
  automatisch die Button-Traits.
- Status wird NIE nur über Farbe vermittelt — Icon-Form (Kreis/Haken/Minus)
  UND Text ("Offen"/"Erfasst"/"Übersprungen") sind immer beide vorhanden
  (`accessibilityDifferentiateWithoutColor`-sicher).
- Timer-Anzeige nutzt `.accessibilityAddTraits(.updatesFrequently)` (bereits
  etabliertes Muster aus der Vorfassung) statt VoiceOver bei jedem Tick neu
  ansagen zu lassen.
- Mindest-Tap-Fläche 44×44 auf allen Buttons, auch den kompakten
  Übersichts-Icons.
- Bei `@Environment(\.accessibilityReduceMotion) == true` keine große
  Bewegungs-Animation beim Karten-Statuswechsel — nur Opacity-Überblendung
  (bestehende `.easeInOut`-Dauer bleibt kurz genug, zusätzlich auf
  reinen Opacity-Fade reduziert).
- Primär-/Sekundäraktionen behalten immer einen Text-Label (nie
  icon-only ohne `accessibilityLabel`/sichtbaren Text).

## 8. iPhone-SE- / Dynamic-Type-Layout

- Übersichts-Karten sind EINSPALTIG (keine Grid-Kacheln) — bleibt bei
  Accessibility-Schriftgrößen lesbar, ohne Zeilenumbruch-Kollisionen.
- Lange Familiennamen/Status-Texte: `lineLimit(2)` statt harter Kürzung;
  kein manuelles Trennzeichen.
- Timer-Ziffern bleiben groß (`.system(size: 44, weight: .bold, design:
  .rounded)`, bestehend) — auf einem leeren, fokussierten Bildschirm
  (keine konkurrierenden Elemente mehr dank Trennung von Timer/Stepper,
  siehe §5.2) bleibt das auch auf dem kleinsten unterstützten Gerät
  (iPhone SE, 375pt Breite) unproblematisch.
- Primäraktionen (Start/Pause/Speichern/Weiter) sind immer die volle
  Button-Breite oder zumindest klar gruppiert am Bildschirm-Ende — keine
  nebeneinander gequetschten schmalen Buttons mit Kurztext.
- Safety-Karte: zwei Buttons nebeneinander nur, wenn der verfügbare Platz
  reicht; bei `dynamicTypeSize.isAccessibilitySize` stapeln sie sich
  vertikal (gleiches Muster wie die Plan-Alternativ-Zeilen aus Problem 2).

## 9. Datenmodell-Zuordnung (unverändert wiederverwendet)

| UX-Element | Bestehender Typ |
|---|---|
| Sicherheits-Antwort | `SafetyStatus` (`.clear`/`.flagged`) |
| Push-Ergebnis | `PushUpAssessment` / `pushSelfAssessment` |
| Beine-Ergebnis | `ChairSquatAssessment` / `legsSelfAssessment` |
| Ziehen-Ergebnis | `PullAssessment` / `pullSelfAssessment` |
| Rumpf-Ergebnis | `PlankAssessment` (keine Selbsteinschätzung, Epic-Vorgabe) |
| Ausdauer-Ergebnis | `CardioBaseline` |
| Wochenintensität | `FirstWeekIntensity` |
| Timer-Zustand | `PausableTimerState` (Start/Pause/Resume/Cancel/Finish) |
| Gesamt-Ergebnis | `BaselineAssessment` → `BaselineAssessmentEvaluator.evaluate(_:)` → `BaselineBands` |

Keines dieser Typen ändert sich durch dieses UX-Konzept — nur
`BaselineCheckFlowView` (Navigation/Präsentation) wird neu aufgebaut.

## 10. Explizit nicht Teil dieser Änderung

- Keine Anbindung an einen PlanAdapter (weiterhin Phase 4, siehe
  `BaselineAssessmentEvaluator`-Doku) — das Ergebnis bleibt rein informativ.
- Keine neuen Core-Datenfelder, keine Schema-Änderung.
- Keine Kamera-/Video-basierte Wiederholungszählung.
- Reale Geräte-/Simulator-Prüfung (iPhone SE, Dark/Light, Dynamic Type
  Accessibility 2+, VoiceOver) ist mit dieser Linux-Sandbox nicht möglich —
  bleibt vor Merge zwingend nachzuholen (siehe Abschlussbericht).
