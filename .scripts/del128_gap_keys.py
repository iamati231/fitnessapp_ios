#!/usr/bin/env python3
"""
DEL-128 — i18n gap-fill aus dem UX-Polish-Pass-Smoke-Test:
  * Plan-Metadaten (Tage/Wochen) ohne Plural-Branch
  * ActiveSessionBanner ('Gestartet %@', 'Training läuft')
  * Active-Workout-Labels (KG/WDH/SEK/RIR/PACE/PAUSE) — uppercase
    werden NICHT als eigene Keys angelegt; Caller laesst die Lowercase-
    Variante (`unit.reps.short` = "Wdh") durch `.uppercased()` laufen.
    Aber PAUSE/PAUSE-VORBEI brauchen eigene Keys, weil ihre Sprach-
    Varianten nicht durch reine Case-Konvertierung sauber lokalisierbar
    sind.
  * ExerciseCard.targetText (Cardio / Wdh / Sek / Pause inline)
  * WaterTracker source labels (letzte Messung / Profil-Zielgewicht /
    Default 70 kg)

camelCase-Sibling-Konvention durchgehalten (DEL-121-Saga). Manual
%lld-Substitution fuer Plural statt Apple-Format-Pattern.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    # ─── Plan-Metadaten Plurals ─────────────────────────────────────────
    "plan.metadata.days.one": {
        "de": "%lld Tag",
        "en": "%lld day",
        "tr": "%lld gün",
    },
    "plan.metadata.days.other": {
        "de": "%lld Tage",
        "en": "%lld days",
        "tr": "%lld gün",
    },
    "plan.metadata.weeks.one": {
        "de": "%lld Woche",
        "en": "%lld week",
        "tr": "%lld hafta",
    },
    "plan.metadata.weeks.other": {
        "de": "%lld Wochen",
        "en": "%lld weeks",
        "tr": "%lld hafta",
    },

    # ─── ActiveSessionBanner ────────────────────────────────────────────
    "plans.active.startedAt": {
        # %@ = relative-date wie "vor 3 Std" / "3 hours ago" / "3 saat önce"
        # Postfix-Wording: in DE/EN steht "Gestartet ..." voran, in TR
        # bleibt das Verb hintenan ("... önce başladı") — natuerlicher.
        "de": "Gestartet %@",
        "en": "Started %@",
        "tr": "%@ başladı",
    },
    "plans.active.fallbackName": {
        "de": "Training läuft",
        "en": "Workout in progress",
        "tr": "Antrenman devam ediyor",
    },

    # ─── Rest-Timer Labels ──────────────────────────────────────────────
    "rest.timer.label.active": {
        "de": "PAUSE",
        "en": "REST",
        "tr": "MOLA",
    },
    "rest.timer.label.finished": {
        "de": "PAUSE VORBEI",
        "en": "REST OVER",
        "tr": "MOLA BİTTİ",
    },

    # ─── Active-Workout-Labels ──────────────────────────────────────────
    # "PACE" + "RIR" bleiben als internationale Abkuerzungen unlokalisiert
    # — sie sind Fitness-Standard-Vokabular und auf allen drei Maerkten
    # identisch gebrauchlich. Nur "KG" als eigener Key, weil die Buchstaben
    # auch im Active-Set-Layout neben numerischen Werten stehen sollen.
    "unit.kg.upper": {
        "de": "KG",
        "en": "KG",
        "tr": "KG",
    },

    # ─── ExerciseCard.targetText (Plan-Detail-Karten-Subtitle) ─────────
    "exercise.kind.cardio": {
        "de": "Cardio",
        "en": "Cardio",
        "tr": "Kardiyo",
    },
    "exercise.rest.label": {
        "de": "Pause",
        "en": "Rest",
        "tr": "Mola",
    },
    # Format: "%1$lld × %2$@ %3$@ • %4$llds %5$@"
    # → "3 × 6-8 Wdh • 150s Pause"  /  "3 × 6-8 reps • 150s rest"  /
    #   "3 × 6-8 tkr • 150s mola"
    "exercise.target.strengthFormat": {
        "de": "%1$lld × %2$@ %3$@ • %4$llds %5$@",
        "en": "%1$lld × %2$@ %3$@ • %4$llds %5$@",
        "tr": "%1$lld × %2$@ %3$@ • %4$llds %5$@",
    },
    # Format: "%1$@ • %2$llds %3$@"
    # → "Cardio • 150s Pause"  /  "Cardio • 150s rest"  /  "Kardiyo • 150s mola"
    "exercise.target.cardioFormat": {
        "de": "%1$@ • %2$llds %3$@",
        "en": "%1$@ • %2$llds %3$@",
        "tr": "%1$@ • %2$llds %3$@",
    },

    # ─── WaterTracker source labels ─────────────────────────────────────
    "water.source.lastMeasurement": {
        "de": "letzte Messung",
        "en": "last measurement",
        "tr": "son ölçüm",
    },
    "water.source.goalWeight": {
        "de": "Profil-Zielgewicht",
        "en": "profile goal weight",
        "tr": "profil hedef kilo",
    },
    "water.source.defaultFormat": {
        "de": "Standard %lld kg",
        "en": "default %lld kg",
        "tr": "varsayılan %lld kg",
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
    # Audit for parent-leaf collisions
    keys = set(strings.keys())
    collisions = sorted({k for k in keys if any(o != k and o.startswith(k + ".") for o in keys)})
    print(f"DEL-128 catalog inject: added={added}, skipped={skipped}, total={len(strings)}")
    if collisions:
        print("WARN: parent-leaf collisions:")
        for c in collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
