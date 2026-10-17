#!/usr/bin/env python3
"""
DEL-144: Loescht die 4 unused xcstrings-Keys, die der Audit-Pass
(`dead_catalog_v3.py`) im Rahmen des P0-Audits fuer die neue
Spezifikation identifiziert hat.

Pre-Sweep-Verify: Substring-Suche durch ALLE Swift-Sources zeigt KEINE
Vorkommen dieser Keys ausserhalb des Catalogs selbst.

Idempotent: ueberspringt Keys, die schon weg sind.
"""
from __future__ import annotations
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

DEAD_KEYS = [
    "equipmentEditor.section.accessories",
    "profile.body.footerOk",
    "profile.body.plausible",
    "profile.equipment.sheet.title",
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
    print(f"DEL-144 sweep: deleted={deleted}, skipped={skipped}, remaining={len(strings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
