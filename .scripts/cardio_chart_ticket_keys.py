#!/usr/bin/env python3
"""
Follow-up-Ticket ("Lauftrainingsaufbau - Diagramm verbessern", 2026-11-06):
11 neue Keys fuer den "Trainingsaufbau"-Chart in CoachAdjustmentPreviewView
(Achsenbeschriftung, Wochen-Auswahl, Phasen-Legende, dynamische Coaching-
Erklaerung). Idempotent: ueberspringt bereits vorhandene Keys.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "DeltiqUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    "profile.cardio.adjustment.chart.yAxisLabel": {
        "de": "Laufumfang (km/Woche)",
        "en": "Running volume (km/week)",
        "tr": "Koşu hacmi (km/hafta)",
    },
    "profile.cardio.adjustment.chart.weekLabel": {
        "de": "Woche %d",
        "en": "Week %d",
        "tr": "%d. Hafta",
    },
    "profile.cardio.adjustment.chart.plannedVolumeCaption": {
        "de": "Geplanter Laufumfang",
        "en": "Planned running volume",
        "tr": "Planlanan koşu hacmi",
    },
    "profile.cardio.adjustment.chart.weekDelta": {
        "de": "Veränderung zur Vorwoche: %@",
        "en": "Change vs. previous week: %@",
        "tr": "Önceki haftaya göre değişim: %@",
    },
    "profile.cardio.adjustment.chart.phase.buildUp": {
        "de": "Aufbau",
        "en": "Build-up",
        "tr": "Yükleniş",
    },
    "profile.cardio.adjustment.chart.phase.peak": {
        "de": "Spitze",
        "en": "Peak",
        "tr": "Zirve",
    },
    "profile.cardio.adjustment.chart.phase.taper": {
        "de": "Tapering",
        "en": "Tapering",
        "tr": "Yükü azaltma",
    },
    "profile.cardio.adjustment.chart.explanation.rampAndTaper": {
        "de": "Dein Laufumfang steigt schrittweise, damit sich dein Körper an die Belastung gewöhnen kann. Vor dem Wettkampf wird der Umfang reduziert, um die Regeneration zu unterstützen.",
        "en": "Your running volume increases step by step so your body can adapt to the load. It's reduced before race day to support recovery.",
        "tr": "Vücudunun yüke alışması için koşu hacmin kademeli olarak artıyor. Yarış öncesi toparlanmayı desteklemek için hacim azaltılıyor.",
    },
    "profile.cardio.adjustment.chart.explanation.rampNoTaper": {
        "de": "Dein Laufumfang steigt schrittweise bis zum Wettkampf – für eine Tapering-Phase reicht die verbleibende Zeit nicht mehr aus.",
        "en": "Your running volume increases step by step until race day – there's not enough time left for a tapering phase.",
        "tr": "Koşu hacmin yarış gününe kadar kademeli olarak artıyor – yükü azaltma aşaması için yeterli süre kalmadı.",
    },
    "profile.cardio.adjustment.chart.explanation.alreadyAtTargetWithTaper": {
        "de": "Du liegst bereits auf deinem Zielvolumen. Die letzten Wochen vor dem Wettkampf dienen der Erholung, damit du ausgeruht an den Start gehst.",
        "en": "You're already at your target volume. The final weeks before race day are for recovery, so you start well rested.",
        "tr": "Zaten hedef hacmine ulaştın. Yarıştan önceki son haftalar, dinlenmiş başlaman için toparlanmaya ayrıldı.",
    },
    "profile.cardio.adjustment.chart.explanation.steady": {
        "de": "Dein Laufumfang bleibt bis zum Wettkampf stabil auf deinem aktuellen Niveau.",
        "en": "Your running volume stays steady at your current level until race day.",
        "tr": "Koşu hacmin yarış gününe kadar şu anki seviyende sabit kalıyor.",
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
    print(f"Cardio-Chart catalog patch: added={added}, skipped={skipped}, total={len(strings)}")
    if new_key_collisions:
        print("WARN new-key parent-leaf collisions:")
        for c in new_key_collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions among new keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
