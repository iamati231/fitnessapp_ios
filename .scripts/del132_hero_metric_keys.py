#!/usr/bin/env python3
"""
DEL-132 (Phase 1) — Dashboard Hero-Metric Customization keys.

  * 5 Metric-Labels für HeroMetricType (Weight/BodyFat/FFMI/LeanMass/BMI)
    via `heroMetric.{rawValue}.label`-Konvention. Auch verwendet vom
    Settings-Picker, damit Label-Source ein einziges xcstrings-Key ist.
  * Settings-Section-Strings (Title/Footer/Empty) — gespiegelt zum
    `dashboardSettings.section.{active,inactive}.*`-Pattern.

camelCase-Sibling-Konvention durchgehalten — keine Parent-Leaf-
Collisions mit bestehenden `heroMetric`-Keys (es gibt noch keine).
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    # ─── Hero-Metric-Labels (genutzt von Card + Settings-Picker) ────────
    "heroMetric.weight.label": {
        "de": "Gewicht",
        "en": "Weight",
        "tr": "Ağırlık",
    },
    "heroMetric.bodyFatNavy.label": {
        "de": "KFA (Navy)",
        "en": "Body Fat (Navy)",
        "tr": "Yağ Oranı (Navy)",
    },
    "heroMetric.ffmi.label": {
        "de": "FFMI",
        "en": "FFMI",
        "tr": "FFMI",
    },
    "heroMetric.leanMass.label": {
        "de": "Magermasse",
        "en": "Lean Mass",
        "tr": "Yağsız Kütle",
    },
    "heroMetric.bmi.label": {
        "de": "BMI",
        "en": "BMI",
        "tr": "BMI",
    },

    # ─── Settings-Section "Hero-Karten" (analog widget-section) ─────────
    "dashboardSettings.section.hero.title": {
        "de": "Hero-Karten (oben)",
        "en": "Hero Cards (top)",
        "tr": "Üst Kartlar",
    },
    "dashboardSettings.section.hero.footer": {
        "de": "Bis zu 3 Metriken oben am Dashboard. Per Drag-and-Drop sortieren, per Toggle ausblenden.",
        "en": "Up to 3 metrics at the top of the dashboard. Drag to reorder, toggle to hide.",
        "tr": "Panel'in üstünde en fazla 3 metrik. Sıralamak için sürükle, gizlemek için kapat.",
    },
    "dashboardSettings.section.hero.empty": {
        "de": "Keine Hero-Karten aktiv — die obere Reihe ist ausgeblendet.",
        "en": "No hero cards active — the top row is hidden.",
        "tr": "Aktif üst kart yok — üst satır gizlendi.",
    },
    "dashboardSettings.section.heroInactive.title": {
        "de": "Verfügbare Hero-Karten",
        "en": "Available Hero Cards",
        "tr": "Kullanılabilir Üst Kartlar",
    },
    "dashboardSettings.section.heroInactive.footer": {
        "de": "Tippe auf das Plus-Icon, um eine Metrik wieder oben einzublenden.",
        "en": "Tap the plus icon to put a metric back at the top.",
        "tr": "Bir metriği tekrar yukarı eklemek için artı simgesine dokun.",
    },
    "dashboardSettings.section.hero.maxReached": {
        "de": "Maximum 3 Hero-Karten gleichzeitig.",
        "en": "Maximum 3 hero cards at a time.",
        "tr": "Aynı anda en fazla 3 üst kart.",
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
    print(f"DEL-132 catalog inject: added={added}, skipped={skipped}, total={len(strings)}")
    if collisions:
        print("WARN parent-leaf collisions:")
        for c in collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
