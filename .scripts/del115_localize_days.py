"""DEL-115 -- Day-Spec Lokalisierung.

Annotiert jeden `DaySpec(...)` in `ProgramTemplates.swift` mit dem
passenden `localizationKey:` und injiziert die zugehoerigen
`plan.day.*`-Keys (DE/EN/TR) in `Localizable.xcstrings`.

Idempotent: zweiter Lauf reportet 0/0.

Run from project root:
    "C:\\Python314\\python.exe" .scripts/del115_localize_days.py
"""
import json
import os
import re
import sys

ROOT          = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
XCSTRINGS     = os.path.join(ROOT, "Sources", "FitnessAppUI", "Resources", "Localizable.xcstrings")
PROGRAMS_FILE = os.path.join(ROOT, "Sources", "FitnessAppCore", "Programs", "ProgramTemplates.swift")


# Schema: german_name -> (key_suffix, en, tr)
# Final key is "plan.day.<key_suffix>".
DAYS = {
    "Ganzkörper A":              ("fullBodyA",          "Full Body A",            "Tüm Vücut A"),
    "Ganzkörper B":              ("fullBodyB",          "Full Body B",            "Tüm Vücut B"),
    "Ganzkörper C":              ("fullBodyC",          "Full Body C",            "Tüm Vücut C"),
    "Fatburn A":                 ("fatBurnA",           "Fat Burn A",             "Yağ Yakım A"),
    "Fatburn B":                 ("fatBurnB",           "Fat Burn B",             "Yağ Yakım B"),
    "Fatburn C":                 ("fatBurnC",           "Fat Burn C",             "Yağ Yakım C"),
    "Push & Core":               ("pushAndCore",        "Push & Core",            "Push & Merkez"),
    "Pull & Beine":              ("pullAndLegs",        "Pull & Legs",            "Pull & Bacak"),
    "Ganzkörper HIIT":           ("fullBodyHIIT",       "Full Body HIIT",         "Tüm Vücut HIIT"),
    "Push A":                    ("pushA",              "Push A",                 "Push A"),
    "Push B":                    ("pushB",              "Push B",                 "Push B"),
    "Pull A":                    ("pullA",              "Pull A",                 "Pull A"),
    "Pull B":                    ("pullB",              "Pull B",                 "Pull B"),
    "Beine A":                   ("legsA",              "Legs A",                 "Bacak A"),
    "Beine B":                   ("legsB",              "Legs B",                 "Bacak B"),
    "Oberkörper A (Kraft)":      ("upperAStrength",     "Upper A (Strength)",     "Üst Vücut A (Güç)"),
    "Unterkörper A (Kraft)":     ("lowerAStrength",     "Lower A (Strength)",     "Alt Vücut A (Güç)"),
    "Oberkörper B (Volumen)":    ("upperBVolume",       "Upper B (Volume)",       "Üst Vücut B (Hacim)"),
    "Unterkörper B (Volumen)":   ("lowerBVolume",       "Lower B (Volume)",       "Alt Vücut B (Hacim)"),
    "Brust & Rücken A":          ("chestBackA",         "Chest & Back A",         "Göğüs & Sırt A"),
    "Brust & Rücken B":          ("chestBackB",         "Chest & Back B",         "Göğüs & Sırt B"),
    "Schultern & Arme A":        ("shouldersArmsA",     "Shoulders & Arms A",     "Omuz & Kol A"),
    "Schultern & Arme B":        ("shouldersArmsB",     "Shoulders & Arms B",     "Omuz & Kol B"),
    "Brust":                     ("chest",              "Chest",                  "Göğüs"),
    "Rücken":                    ("back",               "Back",                   "Sırt"),
    "Schultern":                 ("shoulders",          "Shoulders",              "Omuz"),
    "Arme":                      ("arms",               "Arms",                   "Kol"),
    "Beine":                     ("legs",               "Legs",                   "Bacak"),
    "Workout A":                 ("workoutA",           "Workout A",              "Antrenman A"),
    "Workout B":                 ("workoutB",           "Workout B",              "Antrenman B"),
    "Tag 1 – Kniebeuge-Tag":     ("squatDay",           "Day 1 - Squat Day",      "Gün 1 - Squat Günü"),
    "Tag 2 – Bankdrück-Tag":     ("benchDay",           "Day 2 - Bench Day",      "Gün 2 - Bench Günü"),
    "Tag 3 – Kreuzhebe-Tag":     ("deadliftDay",        "Day 3 - Deadlift Day",   "Gün 3 - Deadlift Günü"),
    "Unterkörper & Core":        ("lowerAndCore",       "Lower & Core",           "Alt Vücut & Merkez"),
    "Oberkörper & Explosivität": ("upperAndPower",      "Upper & Power",          "Üst Vücut & Patlayıcı Güç"),
    "Strength Ganzkörper A":     ("strengthFullBodyA",  "Strength Full Body A",   "Güç Tüm Vücut A"),
    "Strength Ganzkörper B":     ("strengthFullBodyB",  "Strength Full Body B",   "Güç Tüm Vücut B"),
    "Strength Push":             ("strengthPush",       "Strength Push",          "Güç Push"),
    "Strength Pull":             ("strengthPull",       "Strength Pull",          "Güç Pull"),
    "Strength Legs":             ("strengthLegs",       "Strength Legs",          "Güç Bacak"),
    "Strength Legs (Light)":     ("strengthLegsLight",  "Strength Legs (Light)",  "Güç Bacak (Hafif)"),
    "Easy Run":                  ("easyRun",            "Easy Run",               "Kolay Koşu"),
    "Long Run":                  ("longRun",            "Long Run",               "Uzun Koşu"),
    "Intervalle":                ("intervals",          "Intervals",              "İnterval"),
}


DAYSPEC_RE = re.compile(r'DaySpec\(name:\s*"([^"]+)"')


def validate():
    with open(PROGRAMS_FILE, "r", encoding="utf-8") as f:
        text = f.read()
    names = set(DAYSPEC_RE.findall(text))
    missing = sorted(n for n in names if n not in DAYS)
    if missing:
        print("ERROR: missing DAYS entries:")
        for m in missing:
            print("  -", repr(m))
        sys.exit(1)
    print(f"OK: all {len(names)} unique DaySpec names covered.")
    return names


def patch_programs():
    """Walk every `DaySpec(name: "X", ...)` init. If it doesn't already
    carry `localizationKey:`, inject it right after the name literal."""
    with open(PROGRAMS_FILE, "r", encoding="utf-8") as f:
        text = f.read()

    count = 0

    def repl(m):
        nonlocal count
        name = m.group(1)
        # Check the surrounding context for an existing localizationKey
        # — but our injection always lands right between `name:` and
        # `type:`, so a substring check on the whole match is enough.
        full = m.group(0)
        if "localizationKey:" in full:
            return full
        if name not in DAYS:
            return full
        suffix = DAYS[name][0]
        # Reconstruct: insert `, localizationKey: "plan.day.<suffix>"` right
        # after the name literal, before any subsequent arg.
        count += 1
        return f'DaySpec(name: "{name}", localizationKey: "plan.day.{suffix}"'

    # Only match DaySpec(...) inits where localizationKey isn't already
    # present — we constrain the regex to NOT include any following content,
    # so the lookahead match captures just `DaySpec(name: "X"` and we append
    # the new param.
    new_text = re.sub(
        r'DaySpec\(name:\s*"([^"]+)"(?!\s*,\s*localizationKey:)',
        repl,
        text,
    )

    if new_text == text:
        print("programs: nothing to patch")
        return

    with open(PROGRAMS_FILE, "w", encoding="utf-8") as f:
        f.write(new_text)
    print(f"programs: added localizationKey to {count} DaySpec inits")


def patch_xcstrings():
    with open(XCSTRINGS, "r", encoding="utf-8") as f:
        data = json.load(f)
    strings = data["strings"]

    added = 0
    filled = 0

    def upsert(key, de, en, tr):
        nonlocal added, filled
        if key not in strings:
            strings[key] = {"extractionState": "manual", "localizations": {}}
            added += 1
        entry = strings[key].setdefault("localizations", {})
        for lang_code, val in (("de", de), ("en", en), ("tr", tr)):
            existing = entry.get(lang_code, {}).get("stringUnit", {}).get("value")
            if not existing:
                entry[lang_code] = {"stringUnit": {"state": "translated", "value": val}}
                filled += 1

    for german, (suffix, en, tr) in DAYS.items():
        upsert(f"plan.day.{suffix}", german, en, tr)

    with open(XCSTRINGS, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"xcstrings: added {added} new keys, filled {filled} empty translation slots")


def main():
    print("=" * 60)
    print("DEL-115: Day-Spec Lokalisierung")
    print("=" * 60)
    validate()
    print()
    print("-> ProgramTemplates.swift")
    patch_programs()
    print()
    print("-> Localizable.xcstrings")
    patch_xcstrings()
    print()
    print("Done.")


if __name__ == "__main__":
    main()
