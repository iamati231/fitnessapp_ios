#!/usr/bin/env python3
"""
Running Coach - Herzfrequenz-Trainingszonen: Keys fuer die 5 Zonen-Namen/
-Beschreibungen und die Zustandsmeldungen in RaceProgressDetailView.
Idempotent: ueberspringt bereits vorhandene Keys.

WICHTIG: auf diesem Host muss PYTHONUTF8=1 gesetzt sein, sonst werden
Umlaute beim Schreiben durch Ersatzzeichen (U+FFFD) ersetzt (siehe Vorfall
in race_progress_dashboard_fix_keys.py).
"""
from __future__ import annotations
import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "Sources" / "DeltiqUI" / "Resources" / "Localizable.xcstrings"

KEYS: dict[str, dict[str, str]] = {
    "heartRateZone.1.name": {"de": "Zone 1 – Regeneration", "en": "Zone 1 – Recovery", "tr": "Bölge 1 – Toparlanma"},
    "heartRateZone.1.description": {
        "de": "Sehr lockeres Tempo zur Erholung.",
        "en": "Very easy pace for recovery.",
        "tr": "Toparlanma için çok hafif tempo.",
    },
    "heartRateZone.2.name": {"de": "Zone 2 – Grundlagenausdauer", "en": "Zone 2 – Base endurance", "tr": "Bölge 2 – Temel dayanıklılık"},
    "heartRateZone.2.description": {
        "de": "Lockeres, gut sprechbares Tempo für die aerobe Basis.",
        "en": "Easy, conversational pace for your aerobic base.",
        "tr": "Aerobik taban için hafif, konuşabilir tempo.",
    },
    "heartRateZone.3.name": {"de": "Zone 3 – Aerob", "en": "Zone 3 – Aerobic", "tr": "Bölge 3 – Aerobik"},
    "heartRateZone.3.description": {
        "de": "Moderates, spürbar anstrengenderes Tempo.",
        "en": "Moderate pace, noticeably harder.",
        "tr": "Orta, belirgin şekilde daha zorlu tempo.",
    },
    "heartRateZone.4.name": {"de": "Zone 4 – Schwelle", "en": "Zone 4 – Threshold", "tr": "Bölge 4 – Eşik"},
    "heartRateZone.4.description": {
        "de": "Intensives Tempo nahe deiner Schwelle.",
        "en": "Intense pace near your threshold.",
        "tr": "Eşiğine yakın yoğun tempo.",
    },
    "heartRateZone.5.name": {"de": "Zone 5 – Maximal", "en": "Zone 5 – Maximal", "tr": "Bölge 5 – Maksimal"},
    "heartRateZone.5.description": {
        "de": "Sehr intensives Tempo, nur kurz haltbar.",
        "en": "Very intense pace, sustainable only briefly.",
        "tr": "Çok yoğun, sadece kısa süre sürdürülebilir tempo.",
    },
    "raceProgress.heartRateZones.title": {
        "de": "Herzfrequenzzonen",
        "en": "Heart rate zones",
        "tr": "Kalp atış hızı bölgeleri",
    },
    "raceProgress.heartRateZones.noMaxHeartRate": {
        "de": "Hinterlege deine maximale Herzfrequenz im Profil, um deine Trainingszonen berechnen zu können.",
        "en": "Add your maximum heart rate to your profile to calculate your training zones.",
        "tr": "Antrenman bölgelerini hesaplayabilmek için profiline maksimum kalp atış hızını ekle.",
    },
    "raceProgress.heartRateZones.calculatedNoMeasuredData": {
        "de": "Deine Herzfrequenzzonen basieren auf deiner hinterlegten maximalen Herzfrequenz von %d bpm. Für die Auswertung deiner tatsächlichen Herzfrequenz während der Läufe liegen noch keine Messdaten vor.",
        "en": "Your heart rate zones are based on your stored maximum heart rate of %d bpm. There's no measured data yet for your actual heart rate during runs.",
        "tr": "Kalp atış hızı bölgelerin, kayıtlı maksimum kalp atış hızın olan %d bpm değerine dayanmaktadır. Koşuların sırasındaki gerçek kalp atış hızın için henüz ölçüm verisi yok.",
    },
    "raceProgress.heartRateZones.calculatedWithMeasuredData": {
        "de": "Deine Trainingsherzfrequenz kann anhand deiner berechneten Herzfrequenzzonen eingeordnet werden.",
        "en": "Your training heart rate can be classified using your calculated heart rate zones.",
        "tr": "Antrenman kalp atış hızın, hesaplanan kalp atış hızı bölgelerine göre sınıflandırılabilir.",
    },
    "raceProgress.heartRateZones.maxHeartRateLabel": {
        "de": "Deine maximale Herzfrequenz: %d bpm (manuell hinterlegt)",
        "en": "Your maximum heart rate: %d bpm (manually entered)",
        "tr": "Maksimum kalp atış hızın: %d bpm (manuel olarak girildi)",
    },
    "raceProgress.heartRateZones.measuredInZone": {
        "de": "Dein Durchschnittspuls von %d bpm lag in Zone %d.",
        "en": "Your average heart rate of %d bpm was in zone %d.",
        "tr": "%d bpm ortalama kalp atış hızın, bölge %d içindeydi.",
    },
    "raceProgress.heartRateZones.measuredOutsideZones": {
        "de": "Dein Durchschnittspuls von %d bpm lag außerhalb der berechneten Zonen.",
        "en": "Your average heart rate of %d bpm was outside the calculated zones.",
        "tr": "%d bpm ortalama kalp atış hızın, hesaplanan bölgelerin dışındaydı.",
    },
    "raceProgress.heartRateZones.disclaimer": {
        "de": "Vereinfachte Orientierung anhand deiner HFmax – keine individuell gemessene Laktatschwelle oder medizinisch validierte Trainingsbereiche.",
        "en": "A simplified guide based on your max heart rate – not an individually measured lactate threshold or medically validated training zone.",
        "tr": "Maksimum kalp atış hızına dayalı basitleştirilmiş bir rehber – bireysel olarak ölçülmüş bir laktat eşiği veya tıbbi olarak doğrulanmış antrenman bölgesi değildir.",
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
    print(f"added={added} skipped={skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
