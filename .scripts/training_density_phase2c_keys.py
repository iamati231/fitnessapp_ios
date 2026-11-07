#!/usr/bin/env python3
"""
AI-Running-Coach Phase 2C/2D: Lokalisierungs-Keys fuer TrainingDensityAnalyzer-
Dashboard-Karte und Detailansicht. Idempotent: ueberspringt bereits vorhandene Keys.
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "DeltiqUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    # Widget name (DashboardSettingsView)
    "widget.trainingLoadCard.name": {
        "de": "Trainingsbelastung",
        "en": "Training Load",
        "tr": "Antrenman Yuku",
    },
    # Compact card
    "trainingDensity.card.showDetails": {
        "de": "Details",
        "en": "Details",
        "tr": "Detaylar",
    },
    "trainingDensity.card.daysPerWeek": {
        "de": "%d Tage/Woche",
        "en": "%d days/week",
        "tr": "%d gun/hafta",
    },
    "trainingDensity.card.consecutiveDays": {
        "de": "%d Folgetage",
        "en": "%d consecutive days",
        "tr": "%d ardisik gun",
    },
    # Detail view title
    "trainingDensity.detail.title": {
        "de": "Trainingsbelastung",
        "en": "Training Load",
        "tr": "Antrenman Yuku",
    },
    # Outcomes
    "trainingDensity.outcome.balanced": {
        "de": "Ausgewogene Belastung",
        "en": "Balanced Load",
        "tr": "Dengeli Antrenman Yuku",
    },
    "trainingDensity.outcome.increasingLoad": {
        "de": "Steigende Belastung",
        "en": "Increasing Load",
        "tr": "Artan Antrenman Yuku",
    },
    "trainingDensity.outcome.highTrainingDensity": {
        "de": "Hohe Trainingsdichte",
        "en": "High Training Density",
        "tr": "Yuksek Antrenman Yogunlugu",
    },
    "trainingDensity.outcome.insufficientRecoveryEvidence": {
        "de": "Erholungsdaten fehlen",
        "en": "Recovery Data Insufficient",
        "tr": "Toparlanma Verisi Eksik",
    },
    "trainingDensity.outcome.insufficientData": {
        "de": "Zu wenig Daten",
        "en": "Insufficient Data",
        "tr": "Yetersiz Veri",
    },
    # Detail sections
    "trainingDensity.detail.sectionAssessment": {
        "de": "Bewertung",
        "en": "Assessment",
        "tr": "Degerlendirme",
    },
    "trainingDensity.detail.sectionLoadTrend": {
        "de": "Belastungsentwicklung",
        "en": "Load Development",
        "tr": "Yuk Gelisimi",
    },
    "trainingDensity.detail.sectionLast7Days": {
        "de": "Trainingstage (letzte 7 Tage)",
        "en": "Training Days (last 7 days)",
        "tr": "Antrenman Gunleri (son 7 gun)",
    },
    "trainingDensity.detail.sectionLast14Days": {
        "de": "Trainingstage (letzte 14 Tage)",
        "en": "Training Days (last 14 days)",
        "tr": "Antrenman Gunleri (son 14 gun)",
    },
    "trainingDensity.detail.sectionConsecutive": {
        "de": "Maximale Folgetage",
        "en": "Max Consecutive Days",
        "tr": "Maksimum Ardisik Gunler",
    },
    "trainingDensity.detail.sectionRunGap": {
        "de": "Kurzester Laufabstand",
        "en": "Shortest Run Gap",
        "tr": "En Kisa Kosular Arasi",
    },
    "trainingDensity.detail.sectionStrengthGap": {
        "de": "Kurzester Kraft-Abstand",
        "en": "Shortest Strength Gap",
        "tr": "En Kisa Kuvvet Arasi",
    },
    "trainingDensity.detail.sectionConcerns": {
        "de": "Erkannte Auffälligkeiten",
        "en": "Findings",
        "tr": "Tespitler",
    },
    "trainingDensity.detail.sectionDataGaps": {
        "de": "Fehlende Daten",
        "en": "Missing Data",
        "tr": "Eksik Veriler",
    },
    "trainingDensity.detail.analyzedPeriod": {
        "de": "Analysezeitraum: %d Tage, %d Einheiten",
        "en": "Analyzed: %d days, %d sessions",
        "tr": "Analiz: %d gun, %d seans",
    },
    "trainingDensity.detail.noConcerns": {
        "de": "Keine Auffälligkeiten",
        "en": "No findings",
        "tr": "Tespit yok",
    },
    "trainingDensity.detail.noGapData": {
        "de": "Zu wenig Einheiten für Abstandsberechnung",
        "en": "Too few sessions to calculate gap",
        "tr": "Hesaplama icin yeterli seans yok",
    },
    # Concern labels
    "trainingDensity.concern.highConsecutive": {
        "de": "%d aufeinanderfolgende Trainingstage ohne Ruhetag",
        "en": "%d consecutive training days without a rest day",
        "tr": "%d ardisik antrenman gunu - dinlenme yok",
    },
    "trainingDensity.concern.denseWeek": {
        "de": "%d Trainingstage in den letzten 7 Tagen",
        "en": "%d training days in the last 7 days",
        "tr": "Son 7 gunde %d antrenman gunu",
    },
    "trainingDensity.concern.closeRunGap": {
        "de": "Laufabstand unter 18 Stunden (%.0f Std.)",
        "en": "Run gap under 18 hours (%.0f h)",
        "tr": "Kosular arasi 18 saatten az (%.0f sa)",
    },
    "trainingDensity.concern.deloadActive": {
        "de": "Laufendes Deload-Programm aktiv",
        "en": "Active deload period",
        "tr": "Aktif deload donemi",
    },
    # DataGap labels
    "trainingDensity.dataGap.insufficientHistory": {
        "de": "Nur %d Tage Trainingshistorie vorhanden (mind. 14 empfohlen)",
        "en": "Only %d days of training history available (14+ recommended)",
        "tr": "Sadece %d gunluk antrenman gecmisi mevcut (en az 14 onerilir)",
    },
    "trainingDensity.dataGap.sessionFeeling": {
        "de": "Keine RPE- oder Befindlichkeitsdaten verfügbar",
        "en": "No RPE or session feeling data available",
        "tr": "RPE veya seans hissi verisi mevcut degil",
    },
    "trainingDensity.dataGap.noIntensity": {
        "de": "Keine Lauf-Intensitätsdaten (Herzfrequenz/Dauer) vorhanden",
        "en": "No run intensity data (heart rate/duration) available",
        "tr": "Kos yogunlugu verisi (kalp hizi/sure) mevcut degil",
    },
    # LoadDevelopment labels (reuses 2B outcome)
    "trainingDensity.loadDev.stable": {
        "de": "Stabil",
        "en": "Stable",
        "tr": "Istikrarli",
    },
    "trainingDensity.loadDev.moderateIncrease": {
        "de": "Moderat steigend (+%.0f%%)",
        "en": "Moderately increasing (+%.0f%%)",
        "tr": "Orta duzey artis (+%%%.0f)",
    },
    "trainingDensity.loadDev.significantIncrease": {
        "de": "Deutlich steigend (+%.0f%%)",
        "en": "Significantly increasing (+%.0f%%)",
        "tr": "Belirgin artis (+%%%.0f)",
    },
    "trainingDensity.loadDev.declining": {
        "de": "Rucklaaufig (-%.0f%%)",
        "en": "Declining (-%.0f%%)",
        "tr": "Dususte (-%%%.0f)",
    },
    "trainingDensity.loadDev.highlyVariable": {
        "de": "Stark schwankend (CV=%.0f%%)",
        "en": "Highly variable (CV=%.0f%%)",
        "tr": "Cok degisken (CV=%%%.0f)",
    },
    "trainingDensity.loadDev.insufficientData": {
        "de": "Zu wenig Wochen fuer Trendanalyse",
        "en": "Too few weeks for trend analysis",
        "tr": "Trend analizi icin yeterli hafta yok",
    },
    # Hours format
    "trainingDensity.detail.hours": {
        "de": "%.0f Stunden",
        "en": "%.0f hours",
        "tr": "%.0f saat",
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
    print(f"Phase 2C/2D catalog patch: added={added}, skipped={skipped}, total={len(strings)}")
    if new_key_collisions:
        print("WARN new-key parent-leaf collisions:")
        for c in new_key_collisions:
            print(f"  - {c}")
    else:
        print("OK: no parent-leaf collisions among new keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
