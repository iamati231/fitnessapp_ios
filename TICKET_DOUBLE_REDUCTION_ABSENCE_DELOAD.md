# DEL-??? Doppelreduktion nach Absence-Deload verhindern

## Status
Offen — kein Code geändert, kein Guard eingebaut. Dieses Ticket dient der
fachlichen Klärung, bevor eine Implementierung beginnt.

## Problem

`AbsenceDeload.apply` reduziert Gewichte und speichert keinen
`deloadOriginalWeight`-Snapshot (absichtlich, da der alte Stand nach
Wochen Pause keine gültige Referenz mehr wäre). Das bedeutet:

- Der Schutz in `ProgressionApplicator`, der `.increaseWeight` bei
  gesetztem `deloadOriginalWeight` vetiert, greift hier **nicht**.
- Auch der umgekehrte Fall ist nicht geschützt: zeigt ein Nutzer nach der
  Rückkehr ein `.decreaseWeight`-Verdikt (weniger Wiederholungen als die
  untere Grenze), schreibt `ProgressionApplicator` eine **weitere Reduktion
  auf das bereits reduzierte Comeback-Gewicht**.

## Vollständiger Ablauf heute

```
AbsenceDeload.apply(factor: 0.85)
  → exercise.suggestedWeight = reducedWeight(...)   // z. B. 100 → 85 kg
  → kein deloadOriginalWeight                       // bewusst leer

Nächste Session: Nutzer schafft nur 6 Reps (Untergrenze 8)
  → ProgressionEvaluator → .decreaseWeight
  → ProgressionApplicator.apply → suggestedWeight = 82.5 kg   // 2. Reduktion
```

Eine dritte Reduktion durch den nächsten schlechten Tag ist ebenfalls möglich.

## Unterschiede der drei Reduktionspfade

| Pfad | Signal | Snapshot? | Timer? | Endet wie? |
|---|---|---|---|---|
| Overreaching-Deload | steigende CNS-Last + hartes Gefühl | `deloadOriginalWeight` | `deload_until` | `endDeload()` stellt Original exakt zurück |
| Absence-Comeback | Pause > Schwelle, etablierte Last | keiner | keiner | Progression schreibt Gewicht schrittweise hoch |
| Normale Progression (abwärts) | Reps < untere Grenze | keiner | keiner | Nächste gute Session → aufwärts |

## Warum nicht einfach sperren?

Eine pauschale Sperre (`guard lastAbsenceDeloadAt < 14 days else { skip }`)
wäre falsch:

- Ein Nutzer, der nach dem Comeback wirklich zu viel lädt und echte
  Überlastungszeichen zeigt, soll weiterhin gewarnt und gesenkt werden
  können.
- Die Comeback-Reduktion ist der **neue Stand**. Weitere Korrekturen
  basieren auf diesem Stand, nicht auf dem alten Pre-Pause-Gewicht.
- Ein harter Block würde Progression und Deload-Logik koppeln — zwei
  getrennte Schreiber auf dasselbe Feld.

## Fachliche Fragen vor der Implementierung

1. **Ist eine weitere leistungsbasierte Senkung nach dem Comeback gewollt?**
   Die wissenschaftliche Antwort: Nein, wenn die Ursache die Rückkehr-Schwäche
   ist (Bindegewebe, Technik). Ja, wenn der Nutzer die Comeback-Last schlicht
   überschätzt hat.

2. **Wo ist die Grenze zwischen "noch normaler Rückkehr" und "echter Überlast"?**
   Vorschlag: Wenn ein `.decreaseWeight`-Verdikt innerhalb der ersten
   `N` Kraft-Sessions nach einem `AbsenceDeload.apply` auftritt, gilt es
   als Rückkehr-Rauschen → halten oder ignorieren. Ab Session N+1 läuft
   normale Progression.

3. **Wie wird "nach einem Absence-Deload" detektiert?**
   `AbsenceDeload.lastAppliedKey` (UserDefaults) gibt den Zeitstempel.
   `ProgressionApplicator` hat derzeit keine Kenntnis dieses Keys — der
   müsste injiziert oder über einen neuen Feldwert auf `Exercise`/`WorkoutSession`
   weitergegeben werden.

## Lösungsoptionen (noch keine Entscheidung)

**Option A — Session-Zähler nach Comeback**
Nach `AbsenceDeload.apply` auf `UserProfile` oder ähnlichem einen Zähler
setzen (`comebackSessionsRemaining = 3`). `ProgressionApplicator` zieht
bei jedem Abwärtsverdikt 1 ab und überspringt die Senkung solange > 0.
Einfach, aber der Zähler ist ein weiterer Shared-State.

**Option B — Relativer Boden**
`ProgressionApplicator` prüft: wurde `suggestedWeight` in den letzten
14 Tagen von außen gesenkt (durch einen anderen Schreiber)? Wenn ja,
kein zweites Abwärtsverdikt. Setzt voraus, dass der letzte Schreiber
identifizierbar ist — heute nicht der Fall.

**Option C — RIR-Puffer-Anpassung statt Gewichtssperre**
Statt Gewichtssenkung den `targetRir` für N Sessions nach dem Comeback
erhöhen. Der Nutzer trainiert leichter, ohne dass das Gewicht weiter fällt.
Technisch aufwändiger, fachlich korrekter (Detraining betrifft
Belastungstoleranz, nicht Maximalkraft).

## Verifikationsszenarien (für Tests des zukünftigen Fixes)

- Nutzer kommt nach 30 Tagen Pause zurück, akzeptiert 15 % Comeback-Reduktion,
  schafft in Session 1 nur 6 von 8 Reps: **kein zweites Abwärtsverdikt**.
- Nutzer kommt zurück, akzeptiert Reduktion, schafft in Session 1 die volle
  Wiederholungszahl: **normales Aufwärtsverdikt möglich**.
- Nutzer ohne Absence-Deload schafft zu wenig Reps: **normales Abwärtsverdikt
  bleibt erhalten** (kein übermäßiger Schutz).

## Referenzen

- `Sources/FitnessAppData/AbsenceDeload.swift` — `apply`, `assess`
- `Sources/FitnessAppData/ProgressionApplicator.swift` — `apply`, `evaluateOnly`
- `Sources/FitnessAppCore/Progression/ComebackAdvisor.swift` — `prescription`
- DEL-239 (Absence-Deload-Design), DEL-242 (bekannte Lücke dokumentiert in
  `ComebackAdvisor.swift:127-136`)
- `Tests/FitnessAppDataTests/ProgressionApplicatorDeloadConflictTests.swift` —
  bestehende Veto-Tests für den Overreaching-Pfad
