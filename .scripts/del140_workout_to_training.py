#!/usr/bin/env python3
"""
DEL-140: Konsolidierung deutscher Terminologie — "Workout" → "Training".

User-Decision (Smoke-Test 2026-05-22): durchgaengige "Training"-Linie in
allen DE-Strings. 34 Treffer + Composita werden mechanisch ersetzt:

  Regel-Reihenfolge (wichtig — laengere Patterns zuerst):

  1. `Workout-`   → `Trainings-`  (Composita-Praefix, z.B.
                                   "Workout-Detail" → "Trainings-Detail")
     Catches auch innere Composita wie "Live-Workout-Flow" weil das
     "Workout-" auch dort matched.

  2. `\bWorkouts\b` → `Trainings`  (Plural, standalone oder mit Hyphen-
                                    Grenze wie "Cardio-Workouts")

  3. `\bWorkout\b`  → `Training`   (Singular, standalone)

Nur DE-Werte werden angefasst. EN bleibt "Workout" (englischer Standard-
Begriff), TR auch unveraendert.

Idempotent: zweiter Run findet nichts mehr zu ersetzen.
"""
from __future__ import annotations
import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"


def transform_de(value: str) -> str:
    # Reihenfolge ist kritisch — siehe Doc-Comment oben.
    out = re.sub(r"Workout-", "Trainings-", value)
    out = re.sub(r"\bWorkouts\b", "Trainings", out)
    out = re.sub(r"\bWorkout\b", "Training", out)
    return out


def main() -> int:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    changed = 0
    for key, entry in data.get("strings", {}).items():
        loc = entry.get("localizations", {}).get("de")
        if not loc:
            continue
        unit = loc.get("stringUnit")
        if not unit:
            continue
        old = unit.get("value", "")
        new = transform_de(old)
        if new != old:
            unit["value"] = new
            changed += 1
            print(f"  {key}")
            print(f"    - {old}")
            print(f"    + {new}")
    CATALOG.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print()
    print(f"DEL-140 sweep: changed {changed} DE strings.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
