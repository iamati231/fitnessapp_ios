#!/usr/bin/env python3
"""
AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-
phase1-implementation.md): Keys fuer RaceProgressDetailView + die neue
Dashboard-Karte. Idempotent: ueberspringt bereits vorhandene Keys.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "DeltiqUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    "raceProgress.detail.title": {
        "de": "Wettkampf-Fortschritt",
        "en": "Race progress",
        "tr": "Yarış ilerlemesi",
    },
    "raceProgress.detail.lastAnalyzed": {
        "de": "Zuletzt ausgewertet: %@",
        "en": "Last analyzed: %@",
        "tr": "Son analiz: %@",
    },
    "raceProgress.detail.weeksHeader": {
        "de": "Ausgewertete Wochen",
        "en": "Weeks analyzed",
        "tr": "Analiz edilen haftalar",
    },
    "raceProgress.detail.concernsHeader": {
        "de": "Erkannte Auffälligkeiten",
        "en": "Findings",
        "tr": "Tespitler",
    },
    "raceProgress.detail.dataGapsHeader": {
        "de": "Fehlende oder unklare Daten",
        "en": "Missing or unclear data",
        "tr": "Eksik veya belirsiz veriler",
    },
    "raceProgress.outcome.onTrack": {
        "de": "Du bist auf Kurs für dein Ziel",
        "en": "You're on track for your goal",
        "tr": "Hedefin için yolundasın",
    },
    "raceProgress.outcome.attentionNeeded": {
        "de": "Ein paar Dinge solltest du im Blick behalten",
        "en": "A few things are worth keeping an eye on",
        "tr": "Göz önünde bulundurman gereken birkaç şey var",
    },
    "raceProgress.outcome.offTrack": {
        "de": "Dein aktuelles Ziel ist mit dem bisherigen Training nicht realistisch",
        "en": "Your current goal isn't realistic given your training so far",
        "tr": "Şimdiye kadarki antrenmanına göre mevcut hedefin gerçekçi değil",
    },
    "raceProgress.outcome.insufficientData": {
        "de": "Noch nicht genug Trainingsdaten für eine Einschätzung",
        "en": "Not enough training data yet for an assessment",
        "tr": "Değerlendirme için henüz yeterli antrenman verisi yok",
    },
    "raceProgress.weekFlag.active": {
        "de": "Lauf-Woche",
        "en": "Running week",
        "tr": "Koşu haftası",
    },
    "raceProgress.weekFlag.beforeObservation": {
        "de": "Vor Coaching-Beginn",
        "en": "Before coaching started",
        "tr": "Koçluk öncesi",
    },
    "raceProgress.weekFlag.strengthOnly": {
        "de": "Nur Krafttraining",
        "en": "Strength training only",
        "tr": "Sadece kuvvet antrenmanı",
    },
    "raceProgress.weekFlag.crossTraining": {
        "de": "Anderes Ausdauertraining",
        "en": "Cross-training",
        "tr": "Çapraz antrenman",
    },
    "raceProgress.weekFlag.ambiguous": {
        "de": "Sportart unklar",
        "en": "Activity type unclear",
        "tr": "Aktivite türü belirsiz",
    },
    "raceProgress.weekFlag.gap": {
        "de": "Trainingspause",
        "en": "Training gap",
        "tr": "Antrenman arası",
    },
    "raceProgress.concern.loadIncreasedTooFast": {
        "de": "Dein Laufumfang ist in den letzten %2$d Wochen um %1$d%% gestiegen – das ist ein schneller Anstieg.",
        "en": "Your running volume increased by %1$d%% over the last %2$d weeks – that's a fast ramp-up.",
        "tr": "Koşu hacmin son %2$d haftada %%%1$d arttı – bu hızlı bir artış.",
    },
    "raceProgress.concern.insufficientRecovery": {
        "de": "Dein Laufumfang ist %d Wochen in Folge gestiegen, ohne eine ruhigere Woche dazwischen.",
        "en": "Your running volume has increased for %d consecutive weeks without a lighter week in between.",
        "tr": "Koşu hacmin, arada daha hafif bir hafta olmadan %d hafta üst üste arttı.",
    },
    "raceProgress.concern.volumePlateau": {
        "de": "Dein Laufumfang ist seit %d Wochen nahezu unverändert.",
        "en": "Your running volume has stayed nearly flat for %d weeks.",
        "tr": "Koşu hacmin %d haftadır neredeyse değişmedi.",
    },
    "raceProgress.concern.goalLikelyUnrealistic": {
        "de": "Mit deinem bisherigen Trainingsumfang ist dein aktuelles Ziel bis zum Renndatum wahrscheinlich nicht erreichbar.",
        "en": "Based on your training so far, your current goal is unlikely to be achievable by your race date.",
        "tr": "Şimdiye kadarki antrenmanına göre, yarış tarihine kadar mevcut hedefine ulaşman pek mümkün görünmüyor.",
    },
    "raceProgress.concern.recentTrainingGap": {
        "de": "Du hast seit %d Wochen keine Laufeinheit mehr absolviert.",
        "en": "You haven't logged a run in %d weeks.",
        "tr": "%d haftadır koşu kaydın yok.",
    },
    "raceProgress.dataGap.insufficientHistory": {
        "de": "Erst %1$d von %2$d benötigten Wochen Trainingshistorie vorhanden.",
        "en": "Only %1$d of %2$d needed weeks of training history available so far.",
        "tr": "Şimdilik gereken %2$d haftadan sadece %1$d hafta antrenman geçmişi mevcut.",
    },
    "raceProgress.dataGap.noHeartRateData": {
        "de": "Keine Herzfrequenz-Daten verfügbar.",
        "en": "No heart rate data available.",
        "tr": "Kalp atış hızı verisi mevcut değil.",
    },
    "raceProgress.dataGap.coachingObservationStartUnknown": {
        "de": "Der Beginn deines Coaching-Zeitraums ist noch nicht bekannt.",
        "en": "The start of your coaching period isn't known yet.",
        "tr": "Koçluk döneminin başlangıcı henüz bilinmiyor.",
    },
    "raceProgress.dataGap.ambiguousActivityPresent": {
        "de": "%d Woche(n) mit Ausdauertraining, dessen Sportart unklar ist.",
        "en": "%d week(s) with endurance training of an unclear sport type.",
        "tr": "Spor türü belirsiz dayanıklılık antrenmanı içeren %d hafta.",
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
    print(f"Race-progress Phase 1 catalog patch: added={added}, skipped={skipped}, total={len(strings)}")
    if new_key_collisions:
        print("WARN new-key parent-leaf collisions:")
        for c in new_key_collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions among new keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
