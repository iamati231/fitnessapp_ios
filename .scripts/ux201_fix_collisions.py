#!/usr/bin/env python3
"""
UX-201 follow-up — fix parent-leaf collisions introduced by my earlier
catalog inject.

The Xcode-26.4.1 `GenerateStringSymbols` step refuses to emit Swift
symbols when a key like `foo.bar.empty` (a leaf value) shares its prefix
with another key `foo.bar.empty.title` (treated as a nested namespace).
DEL-121 fixed 41 such collisions; UX-201 accidentally re-introduced
three via `.empty.title` / `.empty.description` additions.

Strategy:
  * Remove the just-added `.empty.title` + `.empty.description` keys.
  * Re-add them with the camelCase suffix (`.emptyTitle` /
    `.emptyDescription`), which sits at the same depth as the existing
    `.empty` leaf — no parent-child relationship, no collision.
  * For `dashboard.trend.*`: the catalog already has
    `dashboard.trend.emptyTitle` / `.emptyDescription` from an earlier
    wave. Reuse those (matching values) instead of injecting duplicates.

Idempotent.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

# Keys to delete (they cause parent-leaf collisions).
TO_DELETE = [
    "dashboard.trophy.empty.title",
    "dashboard.trophy.empty.description",
    "dashboard.history.empty.title",
    "dashboard.history.empty.description",
    "dashboard.trend.empty.title",       # existing dashboard.trend.emptyTitle covers this
    "dashboard.trend.empty.description", # existing dashboard.trend.emptyDescription covers this
]

# Keys to add (or upsert if missing). Same content as before, just with
# the camelCase suffix so they're siblings of `.empty` instead of
# children of it.
TO_ADD: dict[str, dict[str, str]] = {
    "dashboard.trophy.emptyTitle": {
        "de": "Noch keine PRs",
        "en": "No PRs yet",
        "tr": "Henüz PR yok",
    },
    "dashboard.trophy.emptyDescription": {
        "de": "Schließe ein Training ab, um deinen ersten Rekord zu setzen.",
        "en": "Finish a workout to set your first record.",
        "tr": "İlk rekorunu kaydetmek için bir antrenman tamamla.",
    },
    "dashboard.history.emptyTitle": {
        "de": "Noch kein Training gespeichert",
        "en": "No workout saved yet",
        "tr": "Henüz kayıtlı antrenman yok",
    },
    "dashboard.history.emptyDescription": {
        "de": "Starte dein erstes Workout, um Verlauf und Fortschritt zu sehen.",
        "en": "Start your first workout to see history and progress.",
        "tr": "Geçmiş ve ilerlemeyi görmek için ilk antrenmanına başla.",
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
    deleted = 0
    for key in TO_DELETE:
        if strings.pop(key, None) is not None:
            deleted += 1
    added = skipped = 0
    for key, values in TO_ADD.items():
        if key in strings:
            skipped += 1
            continue
        strings[key] = build_entry(values)
        added += 1

    # Find any remaining parent-leaf collisions for an early-warning.
    keys = set(strings.keys())
    collisions = sorted({k for k in keys for other in keys if other.startswith(k + ".")})

    CATALOG.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"UX-201 fix: deleted={deleted}, added={added}, skipped={skipped}, total={len(strings)}")
    if collisions:
        print("WARN: still have parent-leaf collisions:")
        for c in collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions remain.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
