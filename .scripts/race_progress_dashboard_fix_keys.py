#!/usr/bin/env python3
"""
Dashboard-Fix (doppelte Coach-Karten, Herzfrequenz-Formulierung):
1. Force-Update von `raceProgress.dataGap.noHeartRateData` - klarstellen,
   dass ein hinterlegter Maximalpuls im Profil kein Messwert ist.
2. Neue Karte als eigenstaendiger `DashboardWidgetType.raceProgressCard`
   braucht einen Settings-Listennamen.
Nicht idempotent wie race_progress_phase1_keys.py - diese Keys werden
bewusst UEBERSCHRIEBEN statt uebersprungen.
"""
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "DeltiqUI" / "Resources" / "Localizable.xcstrings"

UPDATES: dict[str, dict[str, str]] = {
    "raceProgress.dataGap.noHeartRateData": {
        "de": "Noch keine gemessenen Herzfrequenzdaten in der Laufhistorie verfügbar. Ein hinterlegter Maximalpuls im Profil ist kein Messwert aus deinem Training.",
        "en": "No measured heart rate data in your running history yet. A stored max heart rate in your profile isn't the same as a recorded training measurement.",
        "tr": "Koşu geçmişinde henüz ölçülmüş kalp atış hızı verisi yok. Profilindeki kayıtlı maksimum kalp atış hızı, antrenmanından alınan bir ölçüm değildir.",
    },
    "widget.raceProgressCard.name": {
        "de": "Wettkampf-Fortschritt",
        "en": "Race progress",
        "tr": "Yarış ilerlemesi",
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

    for key, values in UPDATES.items():
        strings[key] = build_entry(values)

    CATALOG.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Updated {len(UPDATES)} keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
