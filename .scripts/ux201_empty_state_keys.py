#!/usr/bin/env python3
"""
UX-201 — Premium Empty-States for Dashboard widgets.

Adds the title/description/CTA xcstrings keys for each widget's empty
layout. Old 1-line keys (`dashboard.trophy.empty`, `dashboard.history.empty`,
`dashboard.recent.empty.hint`, `dashboard.compoundChart.empty.hint`,
`dashboard.trend.empty`) are left in place — they're still referenced by
the auxiliary teaser-text helpers (e.g. `historyTeaserText` for the
3-state count variant), so we don't break anything.

Idempotent — only writes keys that don't exist yet.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    # NOTE: Trophy + History + Trend Empty-State-Title/-Description-Keys
    # liegen NICHT mehr hier — siehe `ux201_fix_collisions.py`. Sie wurden
    # als camelCase-Siblings (`.emptyTitle`/`.emptyDescription`) angelegt,
    # damit kein Parent-Leaf-Conflict mit dem bestehenden `.empty`-Leaf
    # entsteht (Xcode-26.4.1-`GenerateStringSymbols`-Step).

    # ─── Recent Workouts ────────────────────────────────────────────────
    "dashboard.recent.empty.description": {
        "de": "Beende dein erstes Training, dann erscheint es hier mit Dauer, Sätzen und Volumen.",
        "en": "Finish your first workout — it appears here with duration, sets, and volume.",
        "tr": "İlk antrenmanını tamamla — burada süre, set ve hacimle birlikte görünür.",
    },

    # ─── Compound Lifts Chart ───────────────────────────────────────────
    "dashboard.compoundChart.empty.description": {
        "de": "Logge zwei oder mehr Sätze deiner großen Lifts, um die Kurve zu sehen.",
        "en": "Log two or more sets of your main lifts to see the trend.",
        "tr": "Eğriyi görmek için ana liftlerinden iki veya daha fazla set kaydet.",
    },

    # ─── Shared CTAs (re-used across multiple cards) ────────────────────
    "dashboard.empty.cta.startWorkout": {
        "de": "Training starten",
        "en": "Start workout",
        "tr": "Antrenmana başla",
    },
    "dashboard.empty.cta.addMeasurement": {
        "de": "Messung hinzufügen",
        "en": "Add measurement",
        "tr": "Ölçüm ekle",
    },
}


def build_entry(values: dict[str, str]) -> dict:
    return {
        "extractionState": "manual",
        "localizations": {
            lang: {"stringUnit": {"state": "translated", "value": v}}
            for lang, v in values.items()
        },
    }


def main() -> int:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data.setdefault("strings", {})
    added = skipped = 0
    for key, values in KEYS.items():
        if key in strings:
            skipped += 1
            continue
        strings[key] = build_entry(values)
        added += 1
    if added:
        CATALOG.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    print(f"UX-201 catalog inject: added={added}, skipped={skipped}, total={len(strings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
