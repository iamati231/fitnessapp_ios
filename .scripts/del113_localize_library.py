"""DEL-113 — Full Library Translation.

# NOTE: After DEL-116, the canonical EXERCISES + PROGRAMS dicts
# moved to .scripts/del116_authoritative_translations.py. This
# script's dicts may carry pre-DEL-116 values for new annotations
# only; the xcstrings catalog values are owned by del116.

Master automation for the i18n sweep over ExerciseLibraryData.swift +
ProgramTemplates.swift. Self-contained, deterministic, idempotent.

Phases:
    1. Validate every exercise name in ExerciseLibraryData.swift is covered
       by the EXERCISES dict here.
    2. Patch Localizable.xcstrings:
       - inject ~95 new `exercise.name.*` entries (DE/EN/TR, only filling
         empty slots — never overwrites existing translations)
       - inject 14 new `plan.template.*` entries
    3. Patch ExerciseLibraryData.swift in place to add `localizationKey:`
       parameter to every entry that is still missing it.
    4. Patch ProgramTemplates.swift in place to add `localizationKey:` to
       every `ProgramTemplate(...)` initializer that is missing it.

Run from project root:
    "C:\\Python314\\python.exe" .scripts/del113_localize_library.py

Invariants the script DOES NOT touch:
    - The German `name:` strings stay verbatim (ProgramInstantiator + the
      PlanEnvironmentMigrator name-match on raw German). Only NEW lookup-key
      annotations are added.
    - Existing translations in xcstrings (any non-empty stringUnit.value) are
      never overwritten.
"""
import json
import os
import re
import sys

ROOT          = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
XCSTRINGS     = os.path.join(ROOT, "Sources", "FitnessAppUI", "Resources", "Localizable.xcstrings")
LIBRARY_FILE  = os.path.join(ROOT, "Sources", "FitnessAppCore", "Programs", "ExerciseLibraryData.swift")
PROGRAMS_FILE = os.path.join(ROOT, "Sources", "FitnessAppCore", "Programs", "ProgramTemplates.swift")


# ──────────────────────────────────────────────────────────────────────────
# Exercise translations
# ──────────────────────────────────────────────────────────────────────────
# Schema: german_name → (key_suffix, en, tr)
# Final key is "exercise.name.<key_suffix>".
#
# Translation rules:
#   DE = source name verbatim
#   EN = canonical international gym/fitness vocabulary
#   TR = gym-context Turkish — for standard gym lifts we keep the English
#        wording (which is how Turkish gyms actually label them); for
#        casual/fundamental movements we use native Turkish:
#          Liegestütze → Şınav
#          Klimmzug    → Barfiks (Pull-up loanword is rare)
#          Sit-up      → Mekik
#          Crunch      → Karın Mekik
#          Lauf        → Koşu
#          Radfahren   → Bisiklet
#          Schwimmen   → Yüzme
#          Laufband    → Koşu Bandı
EXERCISES = {
    # BARBELL · CHEST
    "Bankdrücken":                       ("benchpress",                "Bench Press",            "Bench Press"),
    "Schrägbankdrücken (aufwärts)":      ("inclineBenchPress",         "Incline Bench Press",    "Incline Bench Press"),
    "Schrägbankdrücken (abwärts)":       ("declineBenchPress",         "Decline Bench Press",    "Decline Bench Press"),
    "Enges Bankdrücken":                  ("closeGripBenchPress",       "Close-Grip Bench Press", "Close-Grip Bench Press"),

    # BARBELL · BACK
    "Kreuzheben (konventionell)":         ("deadlift",                  "Deadlift",               "Deadlift"),
    "Sumo-Kreuzheben":                    ("sumoDeadlift",              "Sumo Deadlift",          "Sumo Deadlift"),
    "Rudern vorgebeugt":                  ("barbellrow",                "Barbell Row",            "Barbell Row"),
    "Pendlay Row":                        ("pendlayRow",                "Pendlay Row",            "Pendlay Row"),
    "T-Bar Rudern":                       ("tBarRow",                   "T-Bar Row",              "T-Bar Row"),

    # BARBELL · SHOULDERS
    "Schulterdrücken (stehend)":          ("overheadpress",             "Overhead Press",         "Overhead Press"),
    "Push Press":                         ("pushPress",                 "Push Press",             "Push Press"),
    "Nackendrücken":                      ("behindNeckPress",           "Behind-the-Neck Press",  "Behind-the-Neck Press"),
    "Shrug (LH)":                   ("barbellShrug",              "Barbell Shrug",          "Barbell Shrug"),

    # BARBELL · LEGS
    "Kniebeuge":                          ("squat",                     "Back Squat",             "Squat"),
    "Front Squat":                        ("frontSquat",                "Front Squat",            "Front Squat"),
    "Zercher Squat":                      ("zercherSquat",              "Zercher Squat",          "Zercher Squat"),
    "Rumänisches Kreuzheben":             ("romanianDeadlift",          "Romanian Deadlift",      "Romanian Deadlift"),
    "Hip Thrust (LH)":                    ("barbellHipThrust",          "Barbell Hip Thrust",     "Barbell Hip Thrust"),
    "Ausfallschritte (LH)":               ("barbellLunge",              "Barbell Lunge",          "Barbell Lunge"),
    "Good Morning":                       ("goodMorning",               "Good Morning",           "Good Morning"),
    "Wadenheben (stehend, LH)":           ("barbellStandingCalfRaise",  "Standing Calf Raise (Barbell)", "Standing Calf Raise (Barbell)"),

    # BARBELL · ARMS
    "Bizeps-Curl (LH)":                    ("barbellCurl",               "Barbell Curl",           "Barbell Curl"),
    "Reverse Curl":                       ("reverseCurl",               "Reverse Curl",           "Reverse Curl"),
    "Skull Crusher":                      ("skullCrusher",              "Skull Crusher",          "Skull Crusher"),

    # DUMBBELL · CHEST
    "Bankdrücken (KH)":                     ("dumbbellBenchPress",        "Dumbbell Bench Press",   "Dumbbell Bench Press"),
    "Schrägbankdrücken aufwärts (KH)":    ("dumbbellInclineBenchPress", "Dumbbell Incline Bench Press", "Dumbbell Incline Bench Press"),
    "Flyes flach (KH)":                   ("dumbbellFlyFlat",           "Dumbbell Fly (Flat)",    "Dumbbell Fly (Flat)"),
    "Flyes Schrägbank (KH)":              ("dumbbellFlyIncline",        "Dumbbell Fly (Incline)", "Dumbbell Fly (Incline)"),

    # DUMBBELL · BACK
    "Rudern einarmig (KH)":                 ("dumbbellRowOneArm",         "One-Arm Dumbbell Row",   "One-Arm Dumbbell Row"),
    "Chest Supported Row (KH)":           ("chestSupportedRowDB",       "Chest-Supported Row (DB)", "Chest-Supported Row (DB)"),
    "Pullover (KH)":                        ("dumbbellPullover",          "Dumbbell Pullover",      "Dumbbell Pullover"),

    # DUMBBELL · SHOULDERS
    "Schulterdrücken (KH)":                 ("dumbbellShoulderPress",     "Dumbbell Shoulder Press", "Dumbbell Shoulder Press"),
    "Seitheben":                          ("lateralRaise",              "Lateral Raise",          "Lateral Raise"),
    "Frontheben":                         ("frontRaise",                "Front Raise",            "Front Raise"),
    "Reverse Flyes (KH)":                 ("reverseFlyDB",              "Reverse Fly (DB)",       "Reverse Fly (DB)"),
    "Shrug (KH)":                           ("dumbbellShrug",             "Dumbbell Shrug",         "Dumbbell Shrug"),

    # DUMBBELL · LEGS
    "Goblet Squat":                       ("gobletSquat",               "Goblet Squat",           "Goblet Squat"),
    "Ausfallschritte (KH)":                 ("dumbbellLunge",             "Dumbbell Lunge",         "Dumbbell Lunge"),
    "Bulgarische Kniebeuge (KH)":         ("bulgarianSplitSquatDB",     "Bulgarian Split Squat (DB)", "Bulgarian Split Squat (DB)"),
    "Rumänisches Kreuzheben (KH)":               ("dumbbellRDL",               "Dumbbell Romanian Deadlift", "Dumbbell Romanian Deadlift"),
    "Step-Up (KH)":                       ("stepUpDB",                  "Step-Up (DB)",           "Step-Up (DB)"),
    "Hip Thrust (KH)":                      ("dumbbellHipThrust",         "Dumbbell Hip Thrust",    "Dumbbell Hip Thrust"),
    "Wadenheben (KH)":                      ("dumbbellCalfRaise",         "Dumbbell Calf Raise",    "Dumbbell Calf Raise"),

    # DUMBBELL · ARMS
    "Bizeps-Curl (KH)":                            ("bicepcurl",                 "Dumbbell Curl",          "Dumbbell Curl"),
    "Hammer Curl":                        ("hammerCurl",                "Hammer Curl",            "Hammer Curl"),
    "Schrägbank-Curl (KH)":                    ("inclineDumbbellCurl",       "Incline Dumbbell Curl",  "Incline Dumbbell Curl"),
    "Konzentrations-Curl (KH)":                ("concentrationCurl",         "Concentration Curl",     "Concentration Curl"),
    "Trizepsstrecker über Kopf (KH)":       ("dumbbellOverheadTricepExtension", "Dumbbell Overhead Tricep Extension", "Dumbbell Overhead Tricep Extension"),
    "Trizepskickback (KH)":               ("dumbbellTricepKickback",    "Dumbbell Tricep Kickback", "Dumbbell Tricep Kickback"),

    # BODYWEIGHT · UPPER
    "Klimmzüge (weit)":                   ("widePullup",                "Wide Pull-up",           "Wide Pull-up"),
    "Klimmzüge (eng/Chin-up)":            ("pullup",                    "Chin-up",                "Chin-up"),
    "Australian Pull-ups":                ("australianPullup",          "Australian Pull-up",     "Australian Pull-up"),
    "Handtuch-Rudern (Türrahmen)":        ("towelRowDoorframe",         "Towel Row (Doorframe)",  "Havlu Sırt Çekişi (Kapı Kasası)"),
    "Liegestütze":                        ("pushup",                    "Push-up",                "Şınav"),
    "Diamant-Liegestütze":                ("diamondPushup",             "Diamond Push-up",        "Elmas Şınav"),
    "Breite Liegestütze":                 ("widePushup",                "Wide Push-up",           "Geniş Şınav"),
    "Dips (Brust)":                       ("chestDip",                  "Chest Dip",              "Chest Dip"),
    "Dips (Trizeps)":                     ("tricepDip",                 "Tricep Dip",             "Tricep Dip"),
    "Pike Liegestütze":                   ("pikePushup",                "Pike Push-up",           "Pike Şınav"),
    "Handstand-Liegestütze":              ("handstandPushup",           "Handstand Push-up",      "Amuda Kalkarak Şınav"),
    "Back Widows":                        ("backWidows",                "Back Widows",            "Back Widows"),

    # BODYWEIGHT · LOWER
    "Kniebeuge (BW)":                     ("bodyweightSquat",           "Bodyweight Squat",       "Vücut Ağırlığı Squat"),
    "Jump Squat":                         ("jumpSquat",                 "Jump Squat",             "Jump Squat"),
    "Ausfallschritte (BW)":               ("bodyweightLunge",           "Bodyweight Lunge",       "Vücut Ağırlığı Lunge"),
    "Box Jump":                           ("boxJump",                   "Box Jump",               "Box Jump"),
    "Wall Sit":                           ("wallSit",                   "Wall Sit",               "Wall Sit"),
    "Sissy Squats (BW)":                  ("sissySquat",                "Sissy Squat",            "Sissy Squat"),
    "Nordic Curls":                       ("nordicCurl",                "Nordic Curl",            "Nordic Curl"),
    "Glute Bridge (BW)":                  ("gluteBridge",               "Glute Bridge",           "Glute Bridge"),
    "Hip Thrust (BW)":                    ("bodyweightHipThrust",       "Bodyweight Hip Thrust",  "Vücut Ağırlığı Hip Thrust"),
    "Wadenheben (BW)":                    ("bodyweightCalfRaise",       "Bodyweight Calf Raise",  "Vücut Ağırlığı Calf Raise"),

    # BODYWEIGHT · CORE
    "Plank":                              ("plank",                     "Plank",                  "Plank"),
    "Seitstütz":                          ("sidePlank",                 "Side Plank",             "Yan Plank"),
    "Mountain Climbers":                  ("mountainClimber",           "Mountain Climbers",      "Mountain Climbers"),
    "Burpees":                            ("burpee",                    "Burpees",                "Burpee"),
    "Crunches (BW)":                      ("crunch",                    "Crunches",               "Karın Mekik"),
    "Beinheben (liegend)":                ("lyingLegRaise",             "Lying Leg Raise",        "Yatarak Bacak Kaldırma"),
    "Sit-ups":                            ("situp",                     "Sit-ups",                "Mekik"),
    "Beinstrecker liegend":               ("lyingLegExtension",         "Lying Leg Extension",    "Yatarak Bacak Açma"),
    "Russian Twists":                     ("russianTwist",              "Russian Twists",         "Russian Twist"),
    "Hanging Leg Raises":                 ("hangingLegRaise",           "Hanging Leg Raises",     "Asılı Bacak Kaldırma"),

    # MACHINE / CABLE · CHEST
    "Kabel Crossover":                    ("cableCrossover",            "Cable Crossover",        "Cable Crossover"),
    "Pec Deck (Butterfly)":               ("pecDeck",                   "Pec Deck (Butterfly)",   "Pec Deck (Butterfly)"),
    "Brustdrücken (Maschine)":                ("chestPressMachine",         "Chest Press Machine",    "Chest Press Machine"),

    # MACHINE / CABLE · BACK
    "Latzug (weit)":                      ("latpulldown",               "Lat Pulldown (Wide)",    "Lat Pulldown (Wide)"),
    "Latzug (eng)":                       ("latPulldownClose",          "Lat Pulldown (Close)",   "Lat Pulldown (Close)"),
    "Kabelrudern sitzend":                ("seatedCableRow",            "Seated Cable Row",       "Seated Cable Row"),

    # MACHINE / CABLE · SHOULDERS
    "Kabel Seitheben":                    ("cableLateralRaise",         "Cable Lateral Raise",    "Cable Lateral Raise"),
    "Face Pull":                          ("facePull",                  "Face Pull",              "Face Pull"),
    "Schulterdrücken (Maschine)":             ("shoulderPressMachine",      "Shoulder Press Machine", "Shoulder Press Machine"),

    # MACHINE / CABLE · ARMS
    "Trizepsdrücken (Kabel)":            ("tricepPushdown",            "Tricep Pushdown",        "Tricep Pushdown"),
    "Trizepsstrecker über Kopf (Kabel)":  ("cableOverheadTricepExtension", "Cable Overhead Tricep Extension", "Cable Overhead Tricep Extension"),
    "Preacher Curl (Maschine)":           ("preacherCurl",              "Preacher Curl (Machine)", "Preacher Curl (Machine)"),
    "Kabel Curl":                         ("cableCurl",                 "Cable Curl",             "Cable Curl"),

    # MACHINE / CABLE · LEGS
    "Beinpresse":                         ("legpress",                  "Leg Press",              "Leg Press"),
    "Beinstrecker":                       ("legExtension",              "Leg Extension",          "Leg Extension"),
    "Beinbeuger liegend":                 ("lyingLegCurl",              "Lying Leg Curl",         "Lying Leg Curl"),
    "Hack Squat":                         ("hackSquat",                 "Hack Squat",             "Hack Squat"),
    "Smith Machine Squat":                ("smithMachineSquat",         "Smith Machine Squat",    "Smith Machine Squat"),
    "Wadenpresse (sitzend)":              ("seatedCalfRaise",           "Seated Calf Raise",      "Seated Calf Raise"),

    # MACHINE / CABLE · CORE
    "Kabel Crunch":                       ("cableCrunch",               "Cable Crunch",           "Cable Crunch"),

    # RESISTANCE BAND
    "Band Pull-Aparts":                   ("bandPullApart",             "Band Pull-Apart",        "Band Pull-Apart"),
    "Banded Squats":                      ("bandedSquat",               "Banded Squat",           "Banded Squat"),
    "Band Curls":                         ("bandCurl",                  "Band Curl",              "Band Curl"),
    "Banded Hip Thrust":                  ("bandedHipThrust",           "Banded Hip Thrust",      "Banded Hip Thrust"),

    # KETTLEBELL
    "Kettlebell Swing":                   ("kettlebellSwing",           "Kettlebell Swing",       "Kettlebell Swing"),
    "Turkish Get-Up":                     ("turkishGetUp",              "Turkish Get-Up",         "Türk Kalkışı"),
    "Kettlebell Goblet Squat":            ("kettlebellGobletSquat",     "Kettlebell Goblet Squat", "Kettlebell Goblet Squat"),
    "Kettlebell Snatch":                  ("kettlebellSnatch",          "Kettlebell Snatch",      "Kettlebell Snatch"),
    "Kettlebell Clean & Press":           ("kettlebellCleanAndPress",   "Kettlebell Clean & Press", "Kettlebell Clean & Press"),
    "Kettlebell Halo":                    ("kettlebellHalo",            "Kettlebell Halo",        "Kettlebell Halo"),

    # CARDIO
    "Freier Lauf":                        ("run",                       "Free Run",               "Serbest Koşu"),
    "Laufband":                           ("treadmill",                 "Treadmill",              "Koşu Bandı"),
    "Radfahren (outdoor)":                ("cycling",                   "Cycling (Outdoor)",      "Bisiklet (Açık Hava)"),
    "Fahrradergometer":                   ("stationaryBike",            "Stationary Bike",        "Kondisyon Bisikleti"),
    "Rudermaschine":                      ("rowingMachine",             "Rowing Machine",         "Kürek Makinesi"),
    "Crosstrainer":                       ("elliptical",                "Elliptical",             "Eliptik Bisiklet"),
    "Stepper":                            ("stairStepper",              "Stair Stepper",          "Stepper"),
    "Schwimmen":                          ("swimming",                  "Swimming",               "Yüzme"),
}


# ──────────────────────────────────────────────────────────────────────────
# Program template translations
# ──────────────────────────────────────────────────────────────────────────
# Schema: id → (key_suffix, en, tr).  DE = the existing `name:` literal.
# Final key is "plan.template.<key_suffix>".
PROGRAMS = {
    "full_body":           ("fullBody3x",        "Full Body 3x",                       "Tüm Vücut 3x"),
    "fat_loss_fullbody":   ("fatBurnFullBody",   "Fat Burn Full Body",                 "Yağ Yakım Tüm Vücut"),
    "home_gym_hero":       ("homeGymHero",       "Home Gym Hero",                      "Ev Salonu Kahramanı"),
    "bodyweight_mastery":  ("bodyweightMastery", "Bodyweight Mastery",                 "Vücut Ağırlığı Ustası"),
    "push_pull_legs":      ("pushPullLegs",      "Push-Pull-Legs",                     "Push-Pull-Legs"),
    "upper_lower":         ("upperLower",        "Upper-Lower Split",                  "Üst-Alt Vücut Bölünmüş"),
    "arnold_split":        ("arnoldSplit",       "Arnold Split",                       "Arnold Split"),
    "bro_split":           ("broSplit",          "Bro Split",                          "Bro Split"),
    "powerlifting_5x5":    ("powerlifting5x5",   "Powerlifting 5x5",                   "Powerlifting 5x5"),
    "powerlifting_3x5":    ("powerlifting3x5",   "Powerlifting 3x5",                   "Powerlifting 3x5"),
    "football_athletic":   ("footballAthletic",  "Football Athletics",                 "Futbol Atletik"),
    "hybrid_beginner":     ("hybridBeginner",    "Hybrid Athlete — Beginner",          "Hibrit Atlet — Başlangıç"),
    "hybrid_balanced":     ("hybridBalanced",    "Hybrid Athlete — Balanced",          "Hibrit Atlet — Dengeli"),
    "hybrid_performance":  ("hybridPerformance", "Hybrid Athlete — Performance",       "Hibrit Atlet — Performans"),
}


# ──────────────────────────────────────────────────────────────────────────
# Phase 1 — extraction + validation
# ──────────────────────────────────────────────────────────────────────────

NAME_RE = re.compile(r'ExerciseTemplateSpec\(\s*name:\s*"([^"]+)"')


def extract_library_names():
    with open(LIBRARY_FILE, "r", encoding="utf-8") as f:
        text = f.read()
    # Only look at the `Self.all` array (before `alternatives`)
    cutoff = text.find("public static let alternatives")
    section = text[:cutoff] if cutoff > 0 else text
    return NAME_RE.findall(section)


PROGRAM_INIT_RE = re.compile(
    r'ProgramTemplate\(\s*\n\s*id:\s*"([^"]+)"\s*,\s*\n\s*name:\s*"([^"]+)"',
    re.MULTILINE
)


def extract_program_entries():
    with open(PROGRAMS_FILE, "r", encoding="utf-8") as f:
        text = f.read()
    return PROGRAM_INIT_RE.findall(text)


def validate():
    """Return (library_names, program_entries) after asserting coverage."""
    library_names = extract_library_names()
    program_entries = extract_program_entries()

    missing_ex = [n for n in library_names if n not in EXERCISES]
    if missing_ex:
        print("ERROR: %d exercises missing from EXERCISES dict:" % len(missing_ex))
        for n in missing_ex:
            print("  -", repr(n))
        sys.exit(1)

    missing_pr = [pid for (pid, _name) in program_entries if pid not in PROGRAMS]
    if missing_pr:
        print("ERROR: %d programs missing from PROGRAMS dict:" % len(missing_pr))
        for n in missing_pr:
            print("  -", n)
        sys.exit(1)

    print("OK: %d library exercises and %d programs covered." % (len(library_names), len(program_entries)))
    return library_names, program_entries


# ──────────────────────────────────────────────────────────────────────────
# Phase 2 — patch xcstrings
# ──────────────────────────────────────────────────────────────────────────

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

    for german, (suffix, en, tr) in EXERCISES.items():
        upsert(f"exercise.name.{suffix}", german, en, tr)

    for pid, (suffix, en, tr) in PROGRAMS.items():
        # DE name is whatever appears in the Swift literal; look it up.
        program_entries = dict(extract_program_entries())
        de = program_entries.get(pid, "")
        if not de:
            print(f"WARN: no DE name found for program id '{pid}', skipping xcstrings entry")
            continue
        upsert(f"plan.template.{suffix}", de, en, tr)

    with open(XCSTRINGS, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"xcstrings: added {added} new keys, filled {filled} empty translation slots")


# ──────────────────────────────────────────────────────────────────────────
# Phase 3 — patch ExerciseLibraryData.swift
# ──────────────────────────────────────────────────────────────────────────
# Strategy: replace each `ExerciseTemplateSpec(name: "<X>" ... )` initializer
# that does NOT already contain `localizationKey:` by appending the parameter
# before the closing `)`. We must preserve indentation and trailing commas
# of subsequent list elements.
#
# We use a multi-pass regex approach: find each spec init by walking through
# the `Self.all` array section, balancing parentheses to find the closing.

def patch_library():
    with open(LIBRARY_FILE, "r", encoding="utf-8") as f:
        text = f.read()

    # Only process the Self.all section
    cutoff = text.find("public static let alternatives")
    if cutoff < 0:
        print("ERROR: couldn't locate `public static let alternatives` marker")
        sys.exit(1)

    head, tail = text[:cutoff], text[cutoff:]
    new_head, n_added = _inject_localization_keys(head)

    new_text = new_head + tail
    if new_text == text:
        print("library: nothing to patch (all entries already annotated)")
        return

    with open(LIBRARY_FILE, "w", encoding="utf-8") as f:
        f.write(new_text)
    print(f"library: added localizationKey to {n_added} entries")


def _inject_localization_keys(text):
    """Walk every `ExerciseTemplateSpec(...)` init in `text`, append
    `localizationKey: "..."` if missing. Returns (new_text, count_added)."""
    result = []
    i = 0
    n = len(text)
    count = 0
    SPEC = "ExerciseTemplateSpec("

    while i < n:
        idx = text.find(SPEC, i)
        if idx < 0:
            result.append(text[i:])
            break
        # Copy everything up to and including the `(`
        result.append(text[i:idx + len(SPEC)])
        i = idx + len(SPEC)

        # Balance parens to find the matching `)`
        depth = 1
        j = i
        in_string = False
        while j < n and depth > 0:
            c = text[j]
            if c == '"' and (j == 0 or text[j - 1] != "\\"):
                in_string = not in_string
            elif not in_string:
                if c == '(':
                    depth += 1
                elif c == ')':
                    depth -= 1
                    if depth == 0:
                        break
            j += 1
        if j >= n:
            # Unbalanced — bail
            result.append(text[i:])
            break

        body = text[i:j]   # content between the parens
        closing_idx = j

        # Extract the exercise name
        m = re.match(r'\s*name:\s*"([^"]+)"', body)
        if not m:
            result.append(text[i:closing_idx + 1])
            i = closing_idx + 1
            continue
        name = m.group(1)

        if "localizationKey:" in body or name not in EXERCISES:
            # Already annotated or no mapping → emit untouched
            result.append(text[i:closing_idx + 1])
            i = closing_idx + 1
            continue

        suffix = EXERCISES[name][0]
        # Append before closing `)`. Detect indentation of the line that
        # contains the `)` so the appended param sits nicely. Strategy:
        # if body already spans multiple lines and ends with a leading
        # indent before `)`, emit `,\n<indent>localizationKey: "..."`
        # using a matching indent. Else inline.
        # We look at the last newline inside `body` to infer indent.
        last_nl = body.rfind("\n")
        if last_nl >= 0:
            # Multi-line spec — find the indent of the last argument line.
            # Look for the line that starts with a parameter (e.g. "recoveryClass:")
            # to copy its leading whitespace.
            # Simpler: grab the indent of the last non-empty line before `)`.
            tail_lines = body[last_nl + 1:]  # text after final newline (whitespace before `)`)
            # We want the indent USED FOR PARAMETERS. Find an earlier param-line.
            param_indent = _find_param_indent(body)
            insert = f",\n{param_indent}localizationKey: \"exercise.name.{suffix}\""
            # Strip trailing whitespace before `)`. Body ended at `closing_idx-1`.
            # We need to handle: maybe body ends like "...recoveryClass: .high\n                             "
            stripped = body.rstrip()
            new_body = stripped + insert + body[len(stripped):]
        else:
            # Single-line spec
            new_body = body.rstrip()
            if new_body.endswith(","):
                new_body = new_body[:-1]
            new_body = new_body + f", localizationKey: \"exercise.name.{suffix}\""

        result.append(new_body)
        result.append(")")
        i = closing_idx + 1
        count += 1

    return ("".join(result), count)


def _find_param_indent(body):
    """Find the leading-whitespace indent used for parameters in a multi-line
    ExerciseTemplateSpec init body. Falls back to a sensible default."""
    # Look for lines that contain "<word>:" (a parameter)
    for line in body.split("\n"):
        m = re.match(r'^(\s+)\w+:\s', line)
        if m:
            return m.group(1)
    return "                             "  # match existing 29-space indent


# ──────────────────────────────────────────────────────────────────────────
# Phase 4 — patch ProgramTemplates.swift
# ──────────────────────────────────────────────────────────────────────────

def patch_programs():
    with open(PROGRAMS_FILE, "r", encoding="utf-8") as f:
        text = f.read()

    count = 0
    new_text = text
    for pid, (suffix, _en, _tr) in PROGRAMS.items():
        # Find the ProgramTemplate(...) literal where id == pid
        # Pattern matches: id: "pid",\n            name: "..."
        pattern = re.compile(
            r'(ProgramTemplate\(\s*\n\s*id:\s*"' + re.escape(pid) + r'"\s*,\s*\n)(\s*)name:\s*"([^"]+)"'
        )
        def repl(m, _suffix=suffix):
            nonlocal count
            indent = m.group(2)
            name_str = m.group(3)
            # If `localizationKey:` already exists in the ProgramTemplate init nearby,
            # don't add it. Look ahead in the source.
            return m.group(0)  # placeholder; we handle in the second pass

        # Simpler: scan if a `localizationKey: "plan.template.<suffix>"` is
        # already attached anywhere in the source. If not, append after `name: "..."`
        existing_marker = f'localizationKey: "plan.template.{suffix}"'
        if existing_marker in new_text:
            continue

        match = pattern.search(new_text)
        if not match:
            print(f"WARN: program id '{pid}' not found in source — skipping")
            continue
        indent = match.group(2)
        name_line_end = match.end()  # right after closing `"` of name value
        # Insert after the name line:  `,\n<indent>localizationKey: "..."`
        insertion = f',\n{indent}localizationKey: "plan.template.{suffix}"'
        new_text = new_text[:name_line_end] + insertion + new_text[name_line_end:]
        count += 1

    if new_text == text:
        print("programs: nothing to patch")
        return

    with open(PROGRAMS_FILE, "w", encoding="utf-8") as f:
        f.write(new_text)
    print(f"programs: added localizationKey to {count} ProgramTemplate inits")


# ──────────────────────────────────────────────────────────────────────────
# Driver
# ──────────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("DEL-113: Full Library Translation")
    print("=" * 60)
    validate()
    print()
    print("-> Phase 2: patch xcstrings")
    patch_xcstrings()
    print()
    print("-> Phase 3: patch ExerciseLibraryData.swift")
    patch_library()
    print()
    print("-> Phase 4: patch ProgramTemplates.swift")
    patch_programs()
    print()
    print("Done.")


if __name__ == "__main__":
    main()
