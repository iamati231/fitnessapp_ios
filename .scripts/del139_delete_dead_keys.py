#!/usr/bin/env python3
"""
DEL-139: Loescht die 28 unused xcstrings-Keys, die der Audit-Pass
(`dead_catalog_v3.py`) identifiziert hat.

Diese Keys wurden in den letzten Refactor-Wellen ersetzt aber nie aus
dem Catalog entfernt — Beispiele:
  * metric.weight/.kfaNavy/.ffmi  → in DEL-132 durch heroMetric.*.label ersetzt
  * dashboard.history.empty etc.  → in UX-201 durch .emptyTitle/.emptyDescription
  * calc.plate.maxBar/.maxTarget  → in 53c09fc Footer-Warning entfernt
  * common.delete/.discard/.edit  → nie eingebaut bzw. ueberall durch
                                    konkretere Action-Labels ersetzt
  * trophy.kind.*                 → durch pr.kind.* (DEL-126) ersetzt

Pre-Sweep-Verify: Substring-Suche durch ALLE Swift-Sources zeigt KEINE
Vorkommen dieser Keys (Audit per `dead_catalog_strict.py` + `_v3.py`
mit substring + Regex-Patterns).

Idempotent: ueberspringt Keys, die schon weg sind.
"""
from __future__ import annotations
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

DEAD_KEYS = [
    "active.confirm.finish.title",
    "calc.plate.maxBar",
    "calc.plate.maxTarget",
    "common.delete",
    "common.discard",
    "common.edit",
    "dashboard.compoundChart.empty.hint",
    "dashboard.recent.empty.hint",
    "dashboard.trend.empty",
    "dashboard.trophy.empty",
    "exercise.name.rest",
    "metric.ffmi",
    "metric.kfaNavy",
    "metric.weight",
    "onboarding.action.create",
    "onboarding.coaching.title",
    "onboarding.field.goal_weight",
    "onboarding.field.height",
    "onboarding.intro.body",
    "onboarding.intro.title",
    "trophy.action.detect",
    "trophy.action.rebuild",
    "trophy.kind.bestSet",
    "trophy.kind.estimated1RM",
    "trophy.kind.heaviestWeight",
    "trophy.kind.maxHoldSeconds",
    "trophy.kind.maxReps",
    "trophy.title",
]


def main() -> int:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data.setdefault("strings", {})
    deleted = 0
    skipped = 0
    for key in DEAD_KEYS:
        if strings.pop(key, None) is not None:
            deleted += 1
        else:
            skipped += 1
    CATALOG.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"DEL-139 sweep: deleted={deleted}, skipped={skipped}, remaining={len(strings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
