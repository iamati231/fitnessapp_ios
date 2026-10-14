# Phase 5 — Konservative Ersatzübungs-Engine

Branch `claude/smart-onboarding-epic`, baut auf Phase 4
(`docs/PLAN_EQUIPMENT_MATCHING_AUDIT.md` Abschnitt 13) auf. Quelle: vom User
hochgeladene `PHASE_5_SUBSTITUTION_IMPLEMENTATION.md` (Implementierungs-
vorschlag, kein Referenz-Swift-Code mitgeliefert — die Core-Engine ist nach
der dort beschriebenen Architektur eigenständig implementiert).

## 1. Reviewed-Regel-Matrix (Schritt 1 der Vorgabe)

Die Vorgabe nennt 7 Kandidaten ausdrücklich als "candidates, NOT automatic
approvals". Geprüft gegen den echten, in Phase 4 annotierten Katalog —
**5 freigegeben, 2 abgelehnt**:

| # | Quelle → Ziel | Status | Gating | Begründung |
|---|---|---|---|---|
| R1 | Flachbank-Kurzhantel-Bankdrücken → "Kurzhantel-Floor-Press" | **Abgelehnt** | — | Ziel existiert nicht im Katalog (nur "Floor Press" [Langhantel] und "Kettlebell Floor Press" [Kettlebell], keine Kurzhantel-Variante). Vorgabe: "If target exercise or GIF does not exist, do not invent a mapping." |
| R2 | Kniebeuge → Goblet Squat (`.any([kettlebell, dumbbell])`) | **Freigegeben** | nur `repsMax >= 10` UND `goal != .strength` | Kniebeuge ist `isSystemCompound`. Ein Goblet Squat kann die Lastkapazität eines schweren Low-Rep-Backsquats nicht ersetzen — Gate schliesst Kraft-Anker-Kontexte explizit aus (Vorgabe: "Heavy low-rep barbell work must not become an alleged equivalent light kettlebell exercise"). |
| R3 | Bulgarische Kniebeuge (KH) → Ausfallschritte (KH) | **Freigegeben** | keines (ausser global) | Beide bereits Kurzhantel-Equipment-Klasse, kein Kraft-Anker. Entfernte erhöhte Fussposition reduziert Balance-/Dehn-Anforderung moderat — Vorschrift bleibt unveraendert, explizit als Grund kommuniziert. |
| R4 | Rudern vorgebeugt (Langhantel) → Chest Supported Row (KH) | **Freigegeben** | `goal != .strength` (isSystemCompound) | NUR die beidarmige, unterstuetzte Variante — NICHT "Rudern einarmig (KH)" (andere Satz-Semantik pro Seite, siehe Vorgabe "review unilateral set semantics"). Rumpfstabilisations-/unterer-Ruecken-Anforderung entfaellt, Vorschrift bleibt unveraendert. |
| R5 | Klimmzüge / Klimmzüge (weit) → Latzug (neutraler Griff) | **Freigegeben** | keines (siehe Limitation unten) | Ziel bestaetigt `.cableStation`-annotiert. Vorgabe verlangt zusaetzlich "goal is not specifically pull-up performance" — es existiert aktuell KEIN solcher `TrainingGoal`-Fall im Katalog; die Einschraenkung hat deshalb derzeit keine erzwingbare Wirkung (dokumentierte Limitation, keine erfundene Sperre). |
| R6 | Chest Supported Row (KH) → Kabelrudern sitzend | **Freigegeben** | `experienceTrack != .starter` | Sitzendes Kabelrudern verlangt MEHR Rumpfstabilisation als die unterstuetzte Variante — fuer Starter laut Vorgabe ("no harder replacement merely to satisfy equipment") ausgeschlossen. |
| R7 | Kettlebell Doppel-Push-Press → einarmige Variante | **Abgelehnt** | — | Vorgabe woertlich: "reject in MVP if bilateral-to-unilateral timing/set semantics are not implemented" — sind sie nicht. Keine Regel, keine Huelle, keine spaetere Attrappe. |

Globale Sperren (gelten VOR jeder Einzel-Regel, nie uebersteuerbar):
- Cardio-Uebungen (`isCardio == true`) werden nie substituiert.
- Nicht-`.workingSet`-Rollen (Warmup/Cooldown) werden nie substituiert.
- Jeder Tag mit `timeFormat != nil` (AMRAP/EMOM/Auf-Zeit/Circuit) wird komplett
  von der Substitution ausgenommen (Vorgabe Abschnitt 4: "reject all
  timed/circuit/AMRAP/EMOM substitutions to reduce risk").
- Nur Uebungen mit `PlanEquipmentGapReason.missing` (definitiv nicht erfuellt)
  sind Substitutions-Kandidaten. `uncertain`/`notAnnotated` werden NIE
  automatisch ersetzt — sie bleiben Klaerungs-Hinweise (Abschnitt 1 der
  Vorgabe, woertlich).
- Eine vorgeschlagene Ersatzuebung muss nach der Pruefung selbst `.satisfied`
  gegen das Profil sein — nicht nur "existiert im Katalog".

**Nicht Teil dieser Phase**: weitere, von der Vorgabe nicht genannte
Substitutions-Paare. Die Vorgabe nennt 7 Kandidaten als Start-Set; dabei
bleibt es bewusst, statt den Scope eigenstaendig zu erweitern.

## 2. Architektur (Core, `FitnessAppCore/Programs/Substitution/`)

- `PlanEquipmentChecker.fullReport(days:against:)` (NEU, additiv): liefert
  JEDE nicht-erfuellte Uebung mit Slot-Position, getrennt nach `missing`
  (Substitutions-Kandidaten) und `uncertain` (Klaerung, nie Substitution) —
  im Unterschied zu `check(days:against:)` (Phase 4, unveraendert), das bei
  der ersten definitiv fehlenden Uebung alle unklaren Geschwister-Funde
  verwirft (Kurzschluss-Aggregation). `check` ist jetzt ueber `fullReport`
  implementiert, exakt gleiches Verhalten, siehe Regressionstest.
- `ExerciseSlot` (dayIndex + exerciseIndex — Namen wiederholen sich ueber Tage).
- `ReviewedSubstitutionRule`: id, Quelle/Ziel-Name, Prioritaet, Reason-Key,
  Context-Pruedikat + Praescriptions-Builder (`(ExerciseSpec, SubstitutionContext) -> ExerciseSpec?`,
  `nil` = Regel gilt in diesem Kontext nicht).
- `ExerciseReplacement`, `PlanAdaptationDraft` (angepasste Tage + alle
  Aenderungen + finaler Equipment-Status NACH Ersatz + Blocker).
- `ExerciseSubstitutionEngine.adapt(...)`: deterministisch, wendet pro
  fehlender Uebung die erste passende, equipment-tatsaechlich-erfuellte
  Regel an; keine Regelketten (ein Ersatz wird nie seinerseits ersetzt).
- `PlanAdaptationValidator`: Programm-Ebene — doppelte Ersatz-Namen am
  selben Tag, verlorene Push/Pull/Legs-Abdeckung.
