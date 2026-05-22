#!/usr/bin/env python3
"""
DEL-141: Personalisierung — Vorname im Onboarding + Dashboard-Greeting.
"""
from __future__ import annotations
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    # ─── Onboarding: Vorname-Section ────────────────────────────────────
    "onboarding.section.name": {
        "de": "Dein Name",
        "en": "Your Name",
        "tr": "Adın",
    },
    "onboarding.field.firstName": {
        "de": "Vorname",
        "en": "First Name",
        "tr": "Ad",
    },
    # CamelCase-Sibling-Pattern statt `.placeholder`/`.footer` Sub-Keys —
    # sonst Parent-Leaf-Collision mit `firstName` als eigenstaendigem
    # Leaf-Value (siehe CONTRIBUTING.md / DEL-121).
    "onboarding.field.firstNamePlaceholder": {
        "de": "Wie dürfen wir dich nennen?",
        "en": "What should we call you?",
        "tr": "Sana nasıl hitap edelim?",
    },
    "onboarding.field.firstNameFooter": {
        "de": "Optional — du kannst das Feld auch leer lassen.",
        "en": "Optional — you can leave this empty.",
        "tr": "İsteğe bağlı — boş bırakabilirsin.",
    },

    # ─── Dashboard: Greeting (6 Keys, 3 Tageszeiten × 2 Namen-Branches) ─
    "dashboard.greeting.morning.named": {
        "de": "Guten Morgen, %@",
        "en": "Good morning, %@",
        "tr": "Günaydın, %@",
    },
    "dashboard.greeting.morning.generic": {
        "de": "Guten Morgen",
        "en": "Good morning",
        "tr": "Günaydın",
    },
    "dashboard.greeting.afternoon.named": {
        "de": "Guten Tag, %@",
        "en": "Good afternoon, %@",
        "tr": "İyi günler, %@",
    },
    "dashboard.greeting.afternoon.generic": {
        "de": "Guten Tag",
        "en": "Good afternoon",
        "tr": "İyi günler",
    },
    "dashboard.greeting.evening.named": {
        "de": "Guten Abend, %@",
        "en": "Good evening, %@",
        "tr": "İyi akşamlar, %@",
    },
    "dashboard.greeting.evening.generic": {
        "de": "Guten Abend",
        "en": "Good evening",
        "tr": "İyi akşamlar",
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
    # Collision-Check
    keys = set(strings.keys())
    collisions = sorted({k for k in keys if any(o != k and o.startswith(k + ".") for o in keys)})
    print(f"DEL-141 catalog inject: added={added}, skipped={skipped}, total={len(strings)}")
    if collisions:
        print("WARN parent-leaf collisions:")
        for c in collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
