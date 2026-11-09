#!/usr/bin/env python3
"""
UI-Ticket ("Tab-Leiste vereinfachen, Fortschritt unter Mehr integrieren,
Werkzeuge als Kacheln", 2026-11-06):

  * 1 neuer Key fuer die "Fortschritt & Messungen"-Zeile unter "Mehr"
    (doppelt genutzt: Navigationszeile UND ProgressOverviewView-Titel).
  * 8 neue Keys fuer ProgressOverviewView (Abschnitt A/B/D) — Abschnitt C
    (Messungshistorie) und alle Empty-States wiederverwenden bestehende
    `measurement.*`/`dashboard.trend.*`-Keys unveraendert.
  * `tab.measurement` wird geloescht: das entfallene `AppTab.measurement`
    war die einzige Verwendung (verifiziert per Projekt-Grep).

Idempotent: ueberspringt bereits vorhandene Keys, loescht nur wenn vorhanden.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "DeltiqUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    "settings.group.progress": {
        "de": "Fortschritt & Messungen",
        "en": "Progress & Measurements",
        "tr": "İlerleme ve Ölçümler",
    },
    "progress.section.current.title": {
        "de": "Aktueller Messstand",
        "en": "Current Measurements",
        "tr": "Güncel Ölçüm Durumu",
    },
    "progress.current.date.label": {
        "de": "Datum",
        "en": "Date",
        "tr": "Tarih",
    },
    "progress.current.weight.label": {
        "de": "Gewicht",
        "en": "Weight",
        "tr": "Ağırlık",
    },
    "progress.section.development.title": {
        "de": "Entwicklung",
        "en": "Development",
        "tr": "Gelişim",
    },
    "progress.development.needMore.title": {
        "de": "Noch keine Entwicklung sichtbar",
        "en": "No trend yet",
        "tr": "Henüz bir gelişim yok",
    },
    "progress.development.needMore.description": {
        "de": "Erfasse mindestens eine weitere Messung, um deinen Verlauf zu sehen.",
        "en": "Log at least one more measurement to see your trend.",
        "tr": "Eğilimini görmek için en az bir ölçüm daha ekle.",
    },
    "progress.development.weightChange.label": {
        "de": "Veränderung (7 Tage)",
        "en": "Change (7 days)",
        "tr": "Değişim (7 gün)",
    },
    "progress.action.newMeasurement": {
        "de": "Neue Messung erfassen",
        "en": "Log New Measurement",
        "tr": "Yeni Ölçüm Ekle",
    },
}

DEAD_KEYS = [
    "tab.measurement",
]


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

    deleted = dead_skipped = 0
    for key in DEAD_KEYS:
        if strings.pop(key, None) is not None:
            deleted += 1
        else:
            dead_skipped += 1

    CATALOG.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    keys = set(strings.keys())
    collisions = sorted({k for k in keys if any(o != k and o.startswith(k + ".") for o in keys)})
    print(f"UI-Ticket catalog patch: added={added}, skipped={skipped}, deleted={deleted}, dead_skipped={dead_skipped}, total={len(strings)}")
    if collisions:
        print("WARN parent-leaf collisions:")
        for c in collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
