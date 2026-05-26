#!/usr/bin/env python3
"""
DEL-142: Tagesanalyse-Catalog-Keys (Day-Editor → DayAnalysisCard).

Sammlung aller Strings, die das Feature braucht:
  * Section-Header + Top-Level-Labels
  * Load-Categories (4 stufen: low/moderate/high/veryHigh)
  * Muscle-Focus-Tier-Labels (primary/secondary/tertiary)
  * Coach-Note-Templates (6 Varianten, Ticket-Scope V1)
  * Empty-State + Rest-Day-Special-Case
  * "Estimated"-Pill für unvollständige Daten

Naming-Convention: alle unter `day.analysis.*` Namespace (siehe Ticket-
Vorschlag). CamelCase-Sibling-Pattern wo nötig.
"""
from __future__ import annotations
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    # ─── Card-Header + Pill ────────────────────────────────────────────
    "day.analysis.title": {
        "de": "Tagesanalyse",
        "en": "Day Analysis",
        "tr": "Gün Analizi",
    },
    "day.analysis.estimated": {
        "de": "Schätzung",
        "en": "Estimate",
        "tr": "Tahmin",
    },

    # ─── Top-Level-Labels ──────────────────────────────────────────────
    # CamelCase-Sibling-Pattern wegen Parent-Leaf-Collision mit
    # `.load.low/.moderate/.high/.veryHigh` und `.muscleFocus.tier.*`.
    "day.analysis.loadLabel": {
        "de": "Belastung",
        "en": "Load",
        "tr": "Yük",
    },
    "day.analysis.muscleFocusLabel": {
        "de": "Muskel-Fokus",
        "en": "Muscle Focus",
        "tr": "Kas Odağı",
    },
    "day.analysis.duration": {
        "de": "Geschätzte Dauer",
        "en": "Estimated Duration",
        "tr": "Tahmini Süre",
    },
    "day.analysis.recovery": {
        "de": "Regeneration",
        "en": "Recovery",
        "tr": "Toparlanma",
    },
    "day.analysis.systemic": {
        "de": "Systemische Last",
        "en": "Systemic Load",
        "tr": "Sistemik Yük",
    },

    # ─── Load-Categories (visuelle Skala grün/gelb/orange/rot) ─────────
    "day.analysis.load.low": {
        "de": "Leicht",
        "en": "Light",
        "tr": "Hafif",
    },
    "day.analysis.load.moderate": {
        "de": "Moderat",
        "en": "Moderate",
        "tr": "Orta",
    },
    "day.analysis.load.high": {
        "de": "Hoch",
        "en": "High",
        "tr": "Yüksek",
    },
    "day.analysis.load.veryHigh": {
        "de": "Sehr hoch",
        "en": "Very High",
        "tr": "Çok Yüksek",
    },

    # ─── Muscle-Focus-Tier-Labels ──────────────────────────────────────
    "day.analysis.muscleFocus.tier.primary": {
        "de": "Primär",
        "en": "Primary",
        "tr": "Birincil",
    },
    "day.analysis.muscleFocus.tier.secondary": {
        "de": "Sekundär",
        "en": "Secondary",
        "tr": "İkincil",
    },
    "day.analysis.muscleFocus.tier.tertiary": {
        "de": "Gering",
        "en": "Minor",
        "tr": "Az",
    },

    # ─── Coach-Note-Templates (6 Varianten, V1) ────────────────────────
    "day.analysis.coachNote.balanced": {
        "de": "Ausgewogener Tag mit solidem Reiz und moderater Ermüdung. Gut planbar.",
        "en": "Balanced session with solid stimulus and moderate fatigue. Easy to plan around.",
        "tr": "Dengeli bir gün — sağlam uyaran, orta düzey yorgunluk. Planlamak kolay.",
    },
    "day.analysis.coachNote.highLocal": {
        "de": "Hoher lokaler Reiz bei moderater Systemlast — klassischer Hypertrophie-Tag.",
        "en": "High local stimulus with moderate systemic load — classic hypertrophy day.",
        "tr": "Yüksek yerel uyaran, orta düzey sistemik yük — klasik hipertrofi günü.",
    },
    "day.analysis.coachNote.compoundHeavy": {
        "de": "Systemisch fordernder Compound-Tag. Plane danach eher Erholung oder einen leichten Oberkörper-Tag.",
        "en": "Systemically demanding compound day. Plan for recovery or a light upper-body day afterwards.",
        "tr": "Sistemik olarak zorlayıcı bir compound günü. Sonrasında toparlanma veya hafif üst vücut günü planla.",
    },
    "day.analysis.coachNote.veryHighStress": {
        "de": "Sehr hohe Belastung. Achte danach besonders auf Schlaf und Nahrung — und plane keinen zweiten harten Tag direkt im Anschluss.",
        "en": "Very high load. Pay extra attention to sleep and food afterwards — and don't stack another hard day right after.",
        "tr": "Çok yüksek yük. Sonrasında uykuya ve beslenmeye özellikle dikkat et — ve hemen ardına başka bir zor gün koyma.",
    },
    "day.analysis.coachNote.lightDeload": {
        "de": "Geringer Reiz — passend für Deload, Technik oder Erhaltung.",
        "en": "Low stimulus — ideal for deload, technique, or maintenance.",
        "tr": "Düşük uyaran — deload, teknik veya koruma için ideal.",
    },
    "day.analysis.coachNote.cardioFocused": {
        "de": "Reiner Cardio-Tag. Halte den Reiz konstant und beobachte die Erholung der Beine bis zum nächsten Krafttag.",
        "en": "Pure cardio day. Keep the stimulus steady and watch leg recovery before the next strength session.",
        "tr": "Tamamen kardiyo gün. Uyaranı sabit tut ve bir sonraki güç gününe kadar bacak toparlanmasını gözle.",
    },

    # ─── Empty + Rest-Day ──────────────────────────────────────────────
    "day.analysis.empty": {
        "de": "Füge Übungen hinzu, um die Tagesanalyse zu sehen.",
        "en": "Add exercises to see the day analysis.",
        "tr": "Gün analizini görmek için egzersiz ekle.",
    },
    "day.analysis.restDay": {
        "de": "Heute ist Ruhetag. Keine relevante Trainingsbelastung geplant.",
        "en": "Today is a rest day. No relevant training load planned.",
        "tr": "Bugün dinlenme günü. Önemli bir antrenman yükü planlanmadı.",
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
    print(f"DEL-142 catalog inject: added={added}, skipped={skipped}, total={len(strings)}")
    if collisions:
        print("WARN parent-leaf collisions:")
        for c in collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
