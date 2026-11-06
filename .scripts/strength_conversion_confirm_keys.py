#!/usr/bin/env python3
"""
Follow-up-Ticket ("Krafttraining bei Laufzieländerung erhalten", 2026-11-06):
3 neue Keys fuer die explizite Bestaetigungs-Sektion in
CoachAdjustmentPreviewView, wenn ein Zielwechsel nur durch Umwandeln
bestehender Krafttage moeglich ist (nie automatisch, nur nach Bestaetigung).
Idempotent: ueberspringt bereits vorhandene Keys.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "DeltiqUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    "profile.cardio.adjustment.strengthConversion.header": {
        "de": "Dein neues Ziel braucht mehr Lauftage",
        "en": "Your new goal needs more running days",
        "tr": "Yeni hedefin daha fazla koşu günü gerektiriyor",
    },
    "profile.cardio.adjustment.strengthConversion.footer": {
        "de": "Dein aktueller Plan hat keine freien Tage mehr dafür. Die oben aufgeführten Krafttage könnten stattdessen zu Lauftagen werden – das geschieht nur, wenn du das unten bestätigst.",
        "en": "Your current plan has no free days left for this. The strength days listed above could become running days instead – this only happens if you confirm it below.",
        "tr": "Mevcut planında bunun için boş gün kalmadı. Yukarıda listelenen kuvvet günleri bunun yerine koşu günlerine dönüştürülebilir – bu yalnızca aşağıda onaylarsan gerçekleşir.",
    },
    "profile.cardio.adjustment.confirmStrengthConversion": {
        "de": "Krafttage in Lauftage umwandeln",
        "en": "Convert strength days to running days",
        "tr": "Kuvvet günlerini koşu günlerine dönüştür",
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
    print(f"Strength-conversion-confirm catalog patch: added={added}, skipped={skipped}, total={len(strings)}")
    if new_key_collisions:
        print("WARN new-key parent-leaf collisions:")
        for c in new_key_collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions among new keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
