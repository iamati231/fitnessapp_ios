#!/usr/bin/env python3
"""
DEL-143: RIR-Tooltip-Bloop Catalog-Keys.

  * 5 Tooltip-Texte (RIR 0 / 1 / 2 / 3 / 4+)
  * Settings-Toggle Title + Description
"""
from __future__ import annotations
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    # ─── Tooltip-Texte (Ticket Mapping) ────────────────────────────────
    "rir.tooltip.0": {
        "de": "Absolutes Muskelversagen — keine weitere Wiederholung möglich.",
        "en": "Absolute failure — no more clean reps possible.",
        "tr": "Tam yetersizlik — başka temiz tekrar mümkün değil.",
    },
    "rir.tooltip.1": {
        "de": "Sehr hart — maximal noch 1 saubere Wiederholung im Tank.",
        "en": "Very hard — only 1 clean rep left in the tank.",
        "tr": "Çok zor — tankta sadece 1 temiz tekrar kaldı.",
    },
    "rir.tooltip.2": {
        "de": "Optimaler Reiz — noch 2 Wiederholungen möglich.",
        "en": "Optimal stimulus — 2 more reps possible.",
        "tr": "Optimal uyaran — 2 tekrar daha mümkün.",
    },
    "rir.tooltip.3": {
        "de": "Moderater Reiz — noch 3 saubere Wiederholungen machbar.",
        "en": "Moderate stimulus — 3 clean reps still doable.",
        "tr": "Orta uyaran — 3 temiz tekrar daha yapılabilir.",
    },
    "rir.tooltip.4plus": {
        "de": "Leichtes Training — ideal für Warm-up oder Deload.",
        "en": "Light training — ideal for warm-up or deload.",
        "tr": "Hafif antrenman — ısınma veya deload için ideal.",
    },

    # ─── Settings-Toggle ───────────────────────────────────────────────
    "settings.training.rirTooltip.title": {
        "de": "RIR-Hilfstexte anzeigen",
        "en": "Show RIR helper texts",
        "tr": "RIR yardım metinlerini göster",
    },
    "settings.training.rirTooltip.description": {
        "de": "Zeigt kurze Erklärungen beim Einstellen der Intensität (Reps in Reserve).",
        "en": "Shows short explanations when setting intensity (Reps in Reserve).",
        "tr": "Yoğunluk ayarlanırken kısa açıklamalar gösterir (Reps in Reserve).",
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
    keys = set(strings.keys())
    collisions = sorted({k for k in keys if any(o != k and o.startswith(k + ".") for o in keys)})
    print(f"DEL-143 catalog inject: added={added}, skipped={skipped}, total={len(strings)}")
    if collisions:
        print("WARN parent-leaf collisions:")
        for c in collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
