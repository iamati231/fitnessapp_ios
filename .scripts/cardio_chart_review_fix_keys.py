#!/usr/bin/env python3
"""
Review-Follow-up ("Lauftrainingsdiagramm - Wochenzuordnung, UI-Tests und
Coaching-Erklaerungen korrigieren", 2026-11-06):

  * Neuer Key fuer Woche 0 ("Aktuell" statt "Woche 1" - Part 1 Fix).
  * Die 4 alten, zu grob klassifizierten Erklaerungs-Keys werden durch 5
    praezisere Varianten ersetzt (Part 3 Fix): kontinuierlicher Aufbau,
    Plateau, Entlastungsphase-im-Aufbau, Spitze-erreicht, Tapering.
    Die 4 alten Keys werden geloescht - sie wurden ausschliesslich in
    CoachAdjustmentPreviewView.swift referenziert (dort jetzt entfernt).

Idempotent: ueberspringt bereits vorhandene Keys, loescht nur wenn vorhanden.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "DeltiqUI" / "Resources" / "Localizable.xcstrings"

NEW_KEYS: dict[str, dict[str, str]] = {
    "profile.cardio.adjustment.chart.weekLabel.current": {
        "de": "Aktuell",
        "en": "Now",
        "tr": "Şu an",
    },
    "profile.cardio.adjustment.chart.explanation.continuousBuildUp": {
        "de": "Dein Laufumfang wird schrittweise erhöht, damit sich dein Körper an die steigende Belastung gewöhnen kann.",
        "en": "Your running volume is increased step by step so your body can adapt to the rising load.",
        "tr": "Vücudunun artan yüke alışabilmesi için koşu hacmin kademeli olarak artırılıyor.",
    },
    "profile.cardio.adjustment.chart.explanation.plateau": {
        "de": "Dein Laufumfang bleibt zunächst stabil. So kann sich dein Körper an das erreichte Belastungsniveau gewöhnen.",
        "en": "Your running volume stays steady for now. This lets your body adapt to the load level it has reached.",
        "tr": "Koşu hacmin şimdilik sabit kalıyor. Böylece vücudun ulaştığı yük seviyesine alışabilir.",
    },
    "profile.cardio.adjustment.chart.explanation.deloadWithinBuildUp": {
        "de": "Der Umfang wird vorübergehend reduziert, um die Regeneration zu unterstützen.",
        "en": "The volume is temporarily reduced to support recovery.",
        "tr": "Toparlanmayı desteklemek için hacim geçici olarak azaltılıyor.",
    },
    "profile.cardio.adjustment.chart.explanation.peakReached": {
        "de": "In dieser Phase erreichst du deinen höchsten geplanten Wochenumfang.",
        "en": "In this phase, you reach your highest planned weekly volume.",
        "tr": "Bu aşamada planlanan en yüksek haftalık hacmine ulaşıyorsun.",
    },
    "profile.cardio.adjustment.chart.explanation.taper": {
        "de": "Vor deinem Wettkampf wird der Umfang reduziert, damit du dich erholen und mit frischen Beinen starten kannst.",
        "en": "Before your race, the volume is reduced so you can recover and start with fresh legs.",
        "tr": "Yarışından önce, dinlenip zinde bacaklarla başlayabilmen için hacim azaltılıyor.",
    },
}

DEAD_KEYS = [
    "profile.cardio.adjustment.chart.explanation.rampAndTaper",
    "profile.cardio.adjustment.chart.explanation.rampNoTaper",
    "profile.cardio.adjustment.chart.explanation.alreadyAtTargetWithTaper",
    "profile.cardio.adjustment.chart.explanation.steady",
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
    for key, values in NEW_KEYS.items():
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
    new_key_collisions = [c for c in collisions if c in NEW_KEYS]
    print(f"Review-fix catalog patch: added={added}, skipped={skipped}, deleted={deleted}, dead_skipped={dead_skipped}, total={len(strings)}")
    if new_key_collisions:
        print("WARN new-key parent-leaf collisions:")
        for c in new_key_collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions among new keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
