#!/usr/bin/env python3
"""
PR #57 Review: `PlanBuilderView`s Ergebnisansicht zeigt jetzt sichtbar an,
wenn `PlanAdoptionReadiness.missingLoadLevel` vorliegt, statt nur den
Adopt-Button stumm zu deaktivieren. Idempotent: ueberspringt bereits
vorhandene Keys.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "DeltiqUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    "planBuilder.result.missingLoadLevel.title": {
        "de": "Ladestufe fehlt für einen Tag",
        "en": "Load level missing for one day",
        "tr": "Bir gün için yüklenme seviyesi eksik",
    },
    "planBuilder.result.missingLoadLevel.message": {
        "de": "Für einen Trainingstag konnte keine Belastungseinstufung berechnet werden, deshalb kann der Plan noch nicht übernommen werden. Erstelle einen neuen Vorschlag, um fortzufahren.",
        "en": "A training day is missing its load-level rating, so the plan can't be adopted yet. Create a new proposal to continue.",
        "tr": "Bir antrenman günü için yüklenme seviyesi hesaplanamadığından plan henüz uygulanamıyor. Devam etmek için yeni bir öneri oluştur.",
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
    data = json.loads(CATALOG.read_text(encoding="utf-8-sig"))
    strings = data.setdefault("strings", {})

    added = skipped = 0
    for key, values in KEYS.items():
        if key in strings:
            skipped += 1
            continue
        strings[key] = build_entry(values)
        added += 1

    CATALOG.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    keys = set(strings.keys())
    collisions = sorted({k for k in keys if any(o != k and o.startswith(k + ".") for o in keys)})
    new_key_collisions = [c for c in collisions if c in KEYS]
    print(f"PlanBuilder missing-load-level catalog patch: added={added}, skipped={skipped}, total={len(strings)}")
    if new_key_collisions:
        print("WARN new-key parent-leaf collisions:")
        for c in new_key_collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions among new keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
