#!/usr/bin/env python3
"""
DEL-126/127 — Adds the remaining xcstrings keys needed to finish:
  * WorkoutSummaryView (Zusammenfassung header, stat-labels, Notiz header,
    edit-meta section, toolbar Bearbeiten/Fertig, breakdown footer, PR +
    Progression section headers, Progression badge headlines, unit labels)
  * WorkoutHistoryView session-row fallback "Training", "Min" unit
  * DayEditorView Resume-Button label (DEL-127) + new hint when active
    session is detected for the current day

Idempotent: only writes keys that don't already exist. State="translated".
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    # ─── WorkoutSummaryView ─────────────────────────────────────────────
    "summary.section.stats": {
        "de": "Zusammenfassung",
        "en": "Summary",
        "tr": "Özet",
    },
    "summary.section.personalRecords": {
        "de": "Persönliche Rekorde",
        "en": "Personal Records",
        "tr": "Kişisel Rekorlar",
    },
    "summary.section.progression": {
        "de": "Smart-Progression",
        "en": "Smart Progression",
        "tr": "Akıllı İlerleme",
    },
    "summary.editMeta.header": {
        "de": "Eckdaten",
        "en": "Key Data",
        "tr": "Temel Veriler",
    },
    "summary.editMeta.footer": {
        "de": "Datum + Dauer werden hier überschrieben. Set-Werte unten editierst du direkt am Satz.",
        "en": "Date + duration are overridden here. Edit set values directly on each set below.",
        "tr": "Tarih + süre burada üzerine yazılır. Set değerlerini aşağıda doğrudan her sette düzenle.",
    },
    "summary.toolbar.edit": {
        "de": "Bearbeiten",
        "en": "Edit",
        "tr": "Düzenle",
    },
    "summary.toolbar.done": {
        "de": "Fertig",
        "en": "Done",
        "tr": "Tamam",
    },
    "summary.exercise.bestPrefix": {
        "de": "Beste",
        "en": "Best",
        "tr": "En İyi",
    },
    # Footer: "1 Satz • X kg Volumen" / "N Sätze • X kg Volumen"
    # We use two namespace keys + manual substitution (matches the pattern
    # the codebase already uses to dodge Xcode 26.4.1's symbol-gen step).
    "summary.exercise.footer.one": {
        "de": "%1$lld Satz • %2$@ kg Volumen",
        "en": "%1$lld set • %2$@ kg volume",
        "tr": "%1$lld set • %2$@ kg hacim",
    },
    "summary.exercise.footer.other": {
        "de": "%1$lld Sätze • %2$@ kg Volumen",
        "en": "%1$lld sets • %2$@ kg volume",
        "tr": "%1$lld set • %2$@ kg hacim",
    },

    # ─── Units (short labels) ───────────────────────────────────────────
    "unit.minutes.short": {
        "de": "Min",
        "en": "min",
        "tr": "dk",
    },
    "unit.seconds.short": {
        "de": "Sek",
        "en": "sec",
        "tr": "sn",
    },
    "unit.reps.short": {
        "de": "Wdh",
        "en": "reps",
        "tr": "tkr",
    },

    # ─── Progression badge headlines ────────────────────────────────────
    "progression.headline.increase": {
        "de": "🎯 Ziel erreicht — nächstes Mal mehr",
        "en": "🎯 Goal hit — more next time",
        "tr": "🎯 Hedefe ulaşıldı — bir dahaki sefer daha fazla",
    },
    "progression.headline.deload": {
        "de": "Lass uns kurz zurückrudern",
        "en": "Let's pull back briefly",
        "tr": "Biraz geri çekilelim",
    },
    "progression.detail.newTargetFormat": {
        "de": "Neues Ziel: %@ kg",
        "en": "New target: %@ kg",
        "tr": "Yeni hedef: %@ kg",
    },

    # ─── PR Badge kind-labels ───────────────────────────────────────────
    "pr.kind.estimated1RM": {
        "de": "Neuer 1RM (geschätzt)",
        "en": "New 1RM (estimated)",
        "tr": "Yeni 1TM (tahmini)",
    },
    "pr.kind.heaviestWeight": {
        "de": "Neues Maximalgewicht",
        "en": "New max weight",
        "tr": "Yeni maksimum ağırlık",
    },
    "pr.kind.bestSet": {
        "de": "Neuer Bestsatz (Volumen)",
        "en": "New best set (volume)",
        "tr": "Yeni en iyi set (hacim)",
    },
    "pr.kind.maxReps": {
        "de": "Neuer Reps-Rekord",
        "en": "New reps record",
        "tr": "Yeni tekrar rekoru",
    },
    "pr.kind.maxHoldSeconds": {
        "de": "Neue Bestzeit",
        "en": "New best time",
        "tr": "Yeni en iyi süre",
    },
    "pr.kind.longestDistance": {
        "de": "Längste Distanz",
        "en": "Longest distance",
        "tr": "En uzun mesafe",
    },
    "pr.kind.fastestPace": {
        "de": "Neue Best-Pace",
        "en": "New best pace",
        "tr": "Yeni en iyi tempo",
    },
    "pr.previousShort": {
        "de": "vorher",
        "en": "prev",
        "tr": "önceki",
    },
    "pr.volumeSuffix": {
        "de": "kg-Vol",
        "en": "kg-vol",
        "tr": "kg-hac",
    },

    # ─── History session-row ────────────────────────────────────────────
    "history.session.fallback": {
        "de": "Training",
        "en": "Workout",
        "tr": "Antrenman",
    },

    # ─── DEL-127 Plan-Detail-View Resume-Button ─────────────────────────
    "day.editor.start.resume": {
        "de": "Training fortsetzen",
        "en": "Resume Workout",
        "tr": "Antrenmana Devam Et",
    },
    "day.editor.start.resumeHint": {
        "de": "Eine offene Session zu diesem Tag läuft noch — tippe um sie fortzusetzen.",
        "en": "An open session for this day is still running — tap to resume it.",
        "tr": "Bu güne ait açık bir oturum hâlâ çalışıyor — devam etmek için dokun.",
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
    added = 0
    skipped = 0
    for key, values in KEYS.items():
        if key in strings:
            skipped += 1
            continue
        strings[key] = build_entry(values)
        added += 1
    # Preserve existing key order; new keys are appended at the end.
    # Sorting the whole catalog would create a giant diff.
    if added:
        CATALOG.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    print(f"DEL-126 catalog inject: added={added}, skipped={skipped}, total={len(strings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
