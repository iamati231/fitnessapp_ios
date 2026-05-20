#!/usr/bin/env python3
"""
UX-202 — Workout-Finish Reward-Moment keys.

Adds:
  * Section header for achievements
  * Hero-stat unit suffix labels (Volumen / Distanz / Dauer Heroes)
  * Achievement-Badge texts (weekly milestone + heaviest/longest/
    distance-record of the week)

camelCase-Sibling convention durchgehalten (UX-201 lesson), keine
Parent-Leaf-Collisions mit bestehenden `summary.*`-Keys.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    # ─── Achievements Section ──────────────────────────────────────────
    "summary.achievements.section": {
        "de": "Erfolge",
        "en": "Achievements",
        "tr": "Başarılar",
    },

    # Weekly milestone — "Dein N. Workout diese Woche".
    # Plural-Split via .one / .other (Apple-Format-Pattern verschluckt
    # sich am GenerateStringSymbols-Step — DEL-121-Saga).
    "summary.achievements.weeklyMilestone.titleFormat": {
        "de": "Dein %lld. Workout diese Woche",
        # EN ordinal suffixes (1st/2nd/3rd/4th) waeren ein eigener
        # Formatter-Aufwand — wir umgehen den mit dem "#"-Stempel, der
        # auf englischen Apps weit verbreitet ist.
        "en": "Workout #%lld this week",
        "tr": "Bu haftaki %lld. antrenmanın",
    },
    "summary.achievements.weeklyMilestone.subtitle": {
        "de": "Solides Pensum — bleib dran.",
        "en": "Solid pace — keep going.",
        "tr": "Sağlam tempo — devam et.",
    },

    # Heaviest of week — Volumen-Sieger der Woche
    "summary.achievements.heaviestOfWeek.title": {
        "de": "Stärkstes Workout der Woche",
        "en": "Heaviest workout of the week",
        "tr": "Haftanın en ağır antrenmanı",
    },
    "summary.achievements.heaviestOfWeek.subtitle": {
        "de": "Höchstes Volumen aller bisherigen Trainings dieser Woche.",
        "en": "Highest volume of all your workouts this week so far.",
        "tr": "Bu hafta yaptığın tüm antrenmanların en yüksek hacmi.",
    },

    # Longest of week — Dauer-Sieger
    "summary.achievements.longestOfWeek.title": {
        "de": "Längstes Workout der Woche",
        "en": "Longest workout of the week",
        "tr": "Haftanın en uzun antrenmanı",
    },
    "summary.achievements.longestOfWeek.subtitle": {
        "de": "Du warst diese Woche noch nie so lange dabei.",
        "en": "You haven't trained this long all week.",
        "tr": "Bu hafta hiç bu kadar uzun antrenman yapmamıştın.",
    },

    # Distance record of week (cardio)
    "summary.achievements.longestDistanceOfWeek.title": {
        "de": "Längste Distanz der Woche",
        "en": "Longest distance of the week",
        "tr": "Haftanın en uzun mesafesi",
    },
    "summary.achievements.longestDistanceOfWeek.subtitle": {
        "de": "Mehr Strecke als jedes Cardio diese Woche.",
        "en": "More distance than any cardio this week.",
        "tr": "Bu haftaki tüm kardiyolardan daha uzun.",
    },

    # ─── Hero-Stat Unit Suffixes ────────────────────────────────────────
    # Display unter dem Hero-Number — z.B. "8.400" + "kg Volumen heute".
    # Sind eigene Keys (kein Reuse von active.stats.*), weil sie als
    # vollstaendige Label-Zeile geschrieben sind, nicht als kurzes Stat-
    # Label im Trippel-Layout.
    "summary.hero.unit.volumeKg": {
        "de": "kg Volumen",
        "en": "kg volume",
        "tr": "kg hacim",
    },
    "summary.hero.unit.km": {
        "de": "km Cardio",
        "en": "km cardio",
        "tr": "km kardiyo",
    },
    "summary.hero.unit.minutes": {
        "de": "Minuten Training",
        "en": "minutes training",
        "tr": "dakika antrenman",
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
    # Audit for new collisions
    keys = set(strings.keys())
    collisions = sorted({k for k in keys if any(o != k and o.startswith(k + ".") for o in keys)})
    print(f"UX-202 catalog inject: added={added}, skipped={skipped}, total={len(strings)}")
    if collisions:
        print("WARN: parent-leaf collisions:")
        for c in collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
