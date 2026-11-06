#!/usr/bin/env python3
"""
Running Coach - Herzfrequenz-Trainingszonen (Verifikations-Nachfrage,
Punkt 2): die Klassifikation eines DURCHSCHNITTSPULSES darf nie wie eine
tatsaechlich GEMESSENE ZEIT in einer Zone klingen. Haengt an beide
betroffenen Keys eine explizite Klarstellung an.

WICHTIG: PYTHONUTF8=1 setzen (siehe race_progress_dashboard_fix_keys.py).
Nicht idempotent - diese zwei Keys werden bewusst ueberschrieben.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "DeltiqUI" / "Resources" / "Localizable.xcstrings"

UPDATES: dict[str, dict[str, str]] = {
    "raceProgress.heartRateZones.measuredInZone": {
        "de": "Dein Durchschnittspuls von %d bpm entspricht Zone %d (Einordnung des Durchschnitts, keine gemessene Zeit in der Zone).",
        "en": "Your average heart rate of %d bpm corresponds to zone %d (an average-based classification, not a measured time spent in that zone).",
        "tr": "%d bpm ortalama kalp atış hızın, bölge %d'e karşılık gelir (ortalamaya dayalı sınıflandırma, bölgede ölçülmüş bir süre değildir).",
    },
    "raceProgress.heartRateZones.measuredOutsideZones": {
        "de": "Dein Durchschnittspuls von %d bpm liegt außerhalb der berechneten Zonen (Einordnung des Durchschnitts, keine gemessene Zeit in einer Zone).",
        "en": "Your average heart rate of %d bpm is outside the calculated zones (an average-based classification, not a measured time spent in any zone).",
        "tr": "%d bpm ortalama kalp atış hızın, hesaplanan bölgelerin dışında (ortalamaya dayalı sınıflandırma, herhangi bir bölgede ölçülmüş bir süre değildir).",
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
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"updated {len(UPDATES)} keys")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
