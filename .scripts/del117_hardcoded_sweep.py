"""DEL-117 -- Hardcoded German Strings Sweep.

Centralizes ALL string-migrations (PR1 + PR2) into one dict.  Idempotent
xcstrings injection: only fills empty slots, never overwrites existing.

Run from project root:
    "C:\\Python314\\python.exe" .scripts/del117_hardcoded_sweep.py

The Swift source-file edits are handled separately (per view), since each
requires precise context — Button label vs Text view vs alert message vs
navigationTitle. This script is the SINGLE SOURCE OF TRUTH for the
DE/EN/TR translations.

Convention: dot-namespace keys.  Shared reusable keys live under `common.*`.
String-interpolation tokens use `%@` (text) or `%lld` (integer).
"""
import json
import os

ROOT      = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
XCSTRINGS = os.path.join(ROOT, "Sources", "FitnessAppUI", "Resources", "Localizable.xcstrings")


# Schema: key -> (de, en, tr)
KEYS = {
    # ──────────────────────────────────────────────────────────────────
    # Shared common.* — reused across many views.  Existing keys
    # (common.cancel, common.save, common.done, common.discard) NOT
    # repeated here; this dict only adds NEW shared keys.
    # ──────────────────────────────────────────────────────────────────
    "common.add":     ("Hinzufügen",       "Add",        "Ekle"),
    "common.close":   ("Schließen",        "Close",      "Kapat"),
    "common.back":    ("Zurück",           "Back",       "Geri"),
    "common.edit":    ("Bearbeiten",       "Edit",       "Düzenle"),
    "common.delete":  ("Löschen",          "Delete",     "Sil"),

    # ──────────────────────────────────────────────────────────────────
    # PR1 Batch 1 — 8 smallest files
    # ──────────────────────────────────────────────────────────────────

    # ExerciseCard.swift
    "workout.allSetsDone":      ("Alle Sätze erledigt",     "All sets done",                "Tüm setler tamam"),

    # RestTimerBar.swift
    "rest.skip":                ("Pause überspringen",      "Skip rest",                    "Molayı atla"),

    # DayPickerSheet.swift
    "dayPicker.title":          ("Trainingstage wählen",    "Choose Training Days",         "Antrenman Günleri"),
    "dayPicker.prompt":         ("Wähle exakt %lld Tage, an denen du trainieren möchtest.",
                                  "Choose exactly %lld days you want to train.",
                                  "Antrenman yapmak istediğin tam olarak %lld gün seç."),
    "dayPicker.startPlan":      ("Plan starten",            "Start Plan",                   "Planı Başlat"),

    # SetRow.swift
    "set.numberLabel":          ("Satz %lld",               "Set %lld",                     "Set %lld"),
    "set.lockedHint":           ("Beende oder stoppe die laufende Übung zuerst.",
                                  "Finish or stop the active exercise first.",
                                  "Önce aktif hareketi bitir ya da durdur."),
    "barbell.loading.title":    ("Hantel-Aufladung",        "Barbell Loading",              "Halter Yükleme"),
    "barbell.loading.empty":    ("Keine Aufladung — bleib bei der leeren Stange.",
                                  "No plates needed — keep the empty bar.",
                                  "Plaka yok — boş barı bırak."),

    # ExerciseEditorView.swift
    "editor.exercise.templateLocked": ("Template-Übung — Name und Cardio/Zeit-Flags sind festgelegt.",
                                        "Template exercise — name and cardio/time flags are fixed.",
                                        "Şablon hareket — ad ve kardiyo/süre bayrakları sabit."),
    "editor.exercise.sets":     ("Sätze",                   "Sets",                         "Set"),
    "editor.exercise.rest":     ("Pause",                   "Rest",                         "Mola"),
    "editor.exercise.distanceKm": ("Distanz (km)",          "Distance (km)",                "Mesafe (km)"),
    "editor.exercise.smartOff": ("Aus = das Gewicht wird nie automatisch geändert. Du behältst die volle Kontrolle.",
                                  "Off = weight never auto-adjusts. You stay in full control.",
                                  "Kapalı = ağırlık asla otomatik değişmez. Kontrol sende."),

    # ExercisePickerView.swift
    "picker.exercise.title":    ("Übung wählen",            "Choose Exercise",              "Hareket Seç"),
    "picker.exercise.filterFor": ("Nur Übungen für %@",     "Only %@ exercises",            "Sadece %@ hareketleri"),
    "picker.exercise.filterHint": ("Wenn aus, siehst du auch Übungen, die zu deinem Plan-Typ nicht passen. Die App fragt dann beim Hinzufügen nach, ob du den Plan umstellen willst.",
                                    "When off, you also see exercises that don't fit your plan type. The app asks when adding whether to switch the plan.",
                                    "Kapalıyken plan tipine uymayan hareketleri de görürsün. Eklerken plan değişimi sorulur."),
    "picker.exercise.namePlaceholder": ("Name (z.B. Bankdrücken)",
                                         "Name (e.g. Bench Press)",
                                         "Ad (örn. Bench Press)"),
    "picker.exercise.libraryEmpty": ("Bibliothek ist leer — leg oben deine erste eigene Übung an.",
                                      "Library is empty — create your first custom exercise above.",
                                      "Kütüphane boş — yukarıdan ilk özel hareketini oluştur."),

    # OnboardingQuizView.swift
    "quiz.title":               ("Plan finden",             "Find a Plan",                  "Plan Bul"),
    "quiz.result.topMatch":     ("TOP EMPFEHLUNG FÜR DICH", "TOP MATCH FOR YOU",            "SENİN İÇİN EN İYİ EŞLEŞME"),
    "quiz.result.choose":       ("Diesen Plan wählen",      "Choose This Plan",             "Bu Planı Seç"),

    # ProgramTemplatePickerView.swift
    "picker.plan.title":        ("Programm wählen",         "Choose Program",               "Program Seç"),
    "picker.plan.filterFootnote": ("Gefiltert nach deinem Trainingsort (%@). Im Profil anpassen, wenn du auch andere Pläne sehen willst.",
                                     "Filtered by your training location (%@). Adjust in profile to see other plans.",
                                     "Antrenman yerine göre filtrelendi (%@). Diğer planları görmek için profilden ayarla."),
    "picker.plan.adoptFootnote": ("Beim Übernehmen wird eine Tiefkopie für deine eigene Bibliothek angelegt — Tage, Übungen, Sätze sind danach frei editierbar.",
                                    "Adopting creates a deep copy in your library — days, exercises, and sets are then freely editable.",
                                    "Plan alındığında kütüphanende derin kopya oluşturulur — günler, hareketler ve setler özgürce düzenlenebilir."),
    "plan.dayNumberLabel":      ("Tag %lld",                "Day %lld",                     "Gün %lld"),
}


def upsert(strings, key, de, en, tr):
    """Upsert a key with DE/EN/TR. Only fills empty slots — never
    overwrites existing translations.  Returns (created?, slots_filled)."""
    if key not in strings:
        strings[key] = {"extractionState": "manual", "localizations": {}}
        created = True
    else:
        created = False
    entry = strings[key].setdefault("localizations", {})
    filled = 0
    for code, val in (("de", de), ("en", en), ("tr", tr)):
        existing = entry.get(code, {}).get("stringUnit", {}).get("value")
        if not existing:
            entry[code] = {"stringUnit": {"state": "translated", "value": val}}
            filled += 1
    return created, filled


def main():
    with open(XCSTRINGS, "r", encoding="utf-8") as f:
        data = json.load(f)
    strings = data["strings"]

    created = filled = 0
    for key, (de, en, tr) in KEYS.items():
        c, f = upsert(strings, key, de, en, tr)
        created += int(c)
        filled += f

    with open(XCSTRINGS, "w", encoding="utf-8") as ff:
        json.dump(data, ff, ensure_ascii=False, indent=2)
        ff.write("\n")
    print(f"DEL-117: {created} new keys, {filled} empty translation slots filled")


if __name__ == "__main__":
    main()
