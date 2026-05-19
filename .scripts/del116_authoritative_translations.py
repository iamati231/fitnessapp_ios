"""DEL-116 -- Authoritative Translation Refresh.

User has provided authoritative EN/TR for:
    - all 119 exercises in the Library
    - all 14 Plan-Templates: names + taglines (subtitles)

Additionally generated (this script, autonomous, reviewable in xcstrings):
    - Plan focus translations (8 unique values)
    - Plan descriptionText translations (14)

Phase 1: force-rewrite EN/TR for `exercise.name.*` keys to user's authoritative values.
Phase 2: force-rewrite EN/TR for `plan.template.<id>` keys to user's authoritative names.
Phase 3: inject new `plan.template.<id>.tagline` / `.focus` / `.description` keys.
Phase 4: add 4 new Library entries for orphan ExerciseSpec.name strings
         (Easy Run, Long Run, Intervalle, Gehen / Einlaufen).
Phase 5: rewrite "Cardio / X" prefixes in ProgramTemplates to plain Library names.
Phase 6: keep del113 script's EXERCISES + PROGRAMS dicts in sync with new values.

Idempotent: re-run produces 0 deltas on a fully-applied tree.

Run from project root:
    "C:\\Python314\\python.exe" .scripts/del116_authoritative_translations.py
"""
import json
import os
import re
import sys

ROOT          = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
XCSTRINGS     = os.path.join(ROOT, "Sources", "FitnessAppUI", "Resources", "Localizable.xcstrings")
LIBRARY_FILE  = os.path.join(ROOT, "Sources", "FitnessAppCore", "Programs", "ExerciseLibraryData.swift")
PROGRAMS_FILE = os.path.join(ROOT, "Sources", "FitnessAppCore", "Programs", "ProgramTemplates.swift")


# ────────────────────────────────────────────────────────────────────────
# Authoritative exercise translations (from user CSV)
# Schema: de_name -> (key_suffix, en, tr)
# All 119 Library entries.
# ────────────────────────────────────────────────────────────────────────
EXERCISES = {
    # BARBELL · CHEST
    "Bankdrücken":                          ("benchpress",                "Bench Press",                  "Bench Press"),
    "Schrägbankdrücken (aufwärts)":         ("inclineBenchPress",         "Incline Bench Press",          "Incline Bench Press"),
    "Schrägbankdrücken (abwärts)":          ("declineBenchPress",         "Decline Bench Press",          "Decline Bench Press"),
    "Enges Bankdrücken":                     ("closeGripBenchPress",       "Close-Grip Bench Press",       "Close-Grip Bench Press"),
    # BARBELL · BACK
    "Kreuzheben (konventionell)":            ("deadlift",                  "Conventional Deadlift",        "Conventional Deadlift"),
    "Sumo-Kreuzheben":                       ("sumoDeadlift",              "Sumo Deadlift",                "Sumo Deadlift"),
    "Rudern vorgebeugt":                     ("barbellrow",                "Bent-Over Row",                "Bent-Over Row"),
    "Pendlay Row":                           ("pendlayRow",                "Pendlay Row",                  "Pendlay Row"),
    "T-Bar Rudern":                          ("tBarRow",                   "T-Bar Row",                    "T-Bar Row"),
    # BARBELL · SHOULDERS
    "Schulterdrücken (stehend)":             ("overheadpress",             "Standing Overhead Press",      "Standing Overhead Press"),
    "Push Press":                            ("pushPress",                 "Push Press",                   "Push Press"),
    "Nackendrücken":                         ("behindNeckPress",           "Behind-the-Neck Press",        "Behind-the-Neck Press"),
    "Shrug (LH)":                            ("barbellShrug",              "Barbell Shrug",                "Barbell Shrug"),
    # BARBELL · LEGS
    "Kniebeuge":                             ("squat",                     "Back Squat",                   "Back Squat"),
    "Front Squat":                           ("frontSquat",                "Front Squat",                  "Front Squat"),
    "Zercher Squat":                         ("zercherSquat",              "Zercher Squat",                "Zercher Squat"),
    "Rumänisches Kreuzheben":                ("romanianDeadlift",          "Romanian Deadlift",            "Romanian Deadlift"),
    "Hip Thrust (LH)":                       ("barbellHipThrust",          "Barbell Hip Thrust",           "Barbell Hip Thrust"),
    "Ausfallschritte (LH)":                  ("barbellLunge",              "Barbell Lunges",               "Barbell Lunges"),
    "Good Morning":                          ("goodMorning",               "Good Morning",                 "Good Morning"),
    "Wadenheben (stehend, LH)":              ("barbellStandingCalfRaise",  "Standing Calf Raise (Barbell)", "Standing Calf Raise"),
    # BARBELL · ARMS
    "Bizeps-Curl (LH)":                      ("barbellCurl",               "Barbell Curl",                 "Barbell Curl"),
    "Reverse Curl":                          ("reverseCurl",               "Reverse Curl",                 "Reverse Curl"),
    "Skull Crusher":                         ("skullCrusher",              "Skull Crusher",                "Skull Crusher"),
    # DUMBBELL · CHEST
    "Bankdrücken (KH)":                      ("dumbbellBenchPress",        "Dumbbell Bench Press",         "Dumbbell Bench Press"),
    "Schrägbankdrücken aufwärts (KH)":       ("dumbbellInclineBenchPress", "Incline Dumbbell Bench Press", "Incline Dumbbell Bench Press"),
    "Flyes flach (KH)":                      ("dumbbellFlyFlat",           "Flat Dumbbell Fly",            "Flat Dumbbell Fly"),
    "Flyes Schrägbank (KH)":                 ("dumbbellFlyIncline",        "Incline Dumbbell Fly",         "Incline Dumbbell Fly"),
    # DUMBBELL · BACK
    "Rudern einarmig (KH)":                  ("dumbbellRowOneArm",         "One-Arm Dumbbell Row",         "One-Arm Dumbbell Row"),
    "Chest Supported Row (KH)":              ("chestSupportedRowDB",       "Chest-Supported Dumbbell Row", "Chest-Supported Dumbbell Row"),
    "Pullover (KH)":                         ("dumbbellPullover",          "Dumbbell Pullover",            "Dumbbell Pullover"),
    # DUMBBELL · SHOULDERS
    "Schulterdrücken (KH)":                  ("dumbbellShoulderPress",     "Dumbbell Shoulder Press",      "Dumbbell Shoulder Press"),
    "Seitheben":                             ("lateralRaise",              "Lateral Raise",                "Lateral Raise"),
    "Frontheben":                            ("frontRaise",                "Front Raise",                  "Front Raise"),
    "Reverse Flyes (KH)":                    ("reverseFlyDB",              "Dumbbell Reverse Fly",         "Dumbbell Reverse Fly"),
    "Shrug (KH)":                            ("dumbbellShrug",             "Dumbbell Shrug",               "Dumbbell Shrug"),
    # DUMBBELL · LEGS
    "Goblet Squat":                          ("gobletSquat",               "Goblet Squat",                 "Goblet Squat"),
    "Ausfallschritte (KH)":                  ("dumbbellLunge",             "Dumbbell Lunges",              "Dumbbell Lunges"),
    "Bulgarische Kniebeuge (KH)":            ("bulgarianSplitSquatDB",     "Dumbbell Bulgarian Split Squat", "Dumbbell Bulgarian Split Squat"),
    "Rumänisches Kreuzheben (KH)":           ("dumbbellRDL",               "Dumbbell Romanian Deadlift",   "Dumbbell Romanian Deadlift"),
    "Step-Up (KH)":                          ("stepUpDB",                  "Dumbbell Step-Up",             "Dumbbell Step-Up"),
    "Hip Thrust (KH)":                       ("dumbbellHipThrust",         "Dumbbell Hip Thrust",          "Dumbbell Hip Thrust"),
    "Wadenheben (KH)":                       ("dumbbellCalfRaise",         "Dumbbell Calf Raise",          "Dumbbell Calf Raise"),
    # DUMBBELL · ARMS
    "Bizeps-Curl (KH)":                      ("bicepcurl",                 "Dumbbell Curl",                "Dumbbell Curl"),
    "Hammer Curl":                           ("hammerCurl",                "Hammer Curl",                  "Hammer Curl"),
    "Schrägbank-Curl (KH)":                  ("inclineDumbbellCurl",       "Incline Dumbbell Curl",        "Incline Dumbbell Curl"),
    "Konzentrations-Curl (KH)":              ("concentrationCurl",         "Concentration Curl",           "Concentration Curl"),
    "Trizepsstrecker über Kopf (KH)":        ("dumbbellOverheadTricepExtension", "Overhead Dumbbell Triceps Extension", "Overhead Dumbbell Triceps Extension"),
    "Trizepskickback (KH)":                  ("dumbbellTricepKickback",    "Dumbbell Triceps Kickback",    "Dumbbell Triceps Kickback"),
    # BODYWEIGHT · UPPER
    "Klimmzüge (weit)":                      ("widePullup",                "Wide-Grip Pull-Up",            "Wide-Grip Pull-Up"),
    "Klimmzüge (eng/Chin-up)":               ("pullup",                    "Chin-Up",                      "Barfiks (Chin-Up)"),
    "Australian Pull-ups":                   ("australianPullup",          "Australian Pull-Up",           "Australian Pull-Up"),
    "Handtuch-Rudern (Türrahmen)":           ("towelRowDoorframe",         "Towel Row (Doorframe)",        "Towel Row"),
    "Liegestütze":                           ("pushup",                    "Push-Up",                      "Şınav"),
    "Diamant-Liegestütze":                   ("diamondPushup",             "Diamond Push-Up",              "Diamond Push-Up"),
    "Breite Liegestütze":                    ("widePushup",                "Wide Push-Up",                 "Wide Push-Up"),
    "Dips (Brust)":                          ("chestDip",                  "Chest Dips",                   "Chest Dips"),
    "Dips (Trizeps)":                        ("tricepDip",                 "Triceps Dips",                 "Triceps Dips"),
    "Pike Liegestütze":                      ("pikePushup",                "Pike Push-Up",                 "Pike Push-Up"),
    "Handstand-Liegestütze":                 ("handstandPushup",           "Handstand Push-Up",            "Handstand Push-Up"),
    "Back Widows":                           ("backWidows",                "Back Widow",                   "Back Widow"),
    # BODYWEIGHT · LOWER
    "Kniebeuge (BW)":                        ("bodyweightSquat",           "Bodyweight Squat",             "Bodyweight Squat"),
    "Jump Squat":                            ("jumpSquat",                 "Jump Squat",                   "Jump Squat"),
    "Ausfallschritte (BW)":                  ("bodyweightLunge",           "Bodyweight Lunges",            "Bodyweight Lunges"),
    "Box Jump":                              ("boxJump",                   "Box Jump",                     "Box Jump"),
    "Wall Sit":                              ("wallSit",                   "Wall Sit",                     "Wall Sit"),
    "Sissy Squats (BW)":                     ("sissySquat",                "Sissy Squat",                  "Sissy Squat"),
    "Nordic Curls":                          ("nordicCurl",                "Nordic Curl",                  "Nordic Curl"),
    "Glute Bridge (BW)":                     ("gluteBridge",               "Glute Bridge",                 "Glute Bridge"),
    "Hip Thrust (BW)":                       ("bodyweightHipThrust",       "Bodyweight Hip Thrust",        "Bodyweight Hip Thrust"),
    "Wadenheben (BW)":                       ("bodyweightCalfRaise",       "Bodyweight Calf Raise",        "Bodyweight Calf Raise"),
    # BODYWEIGHT · CORE
    "Plank":                                 ("plank",                     "Plank",                        "Plank"),
    "Seitstütz":                             ("sidePlank",                 "Side Plank",                   "Side Plank"),
    "Mountain Climbers":                     ("mountainClimber",           "Mountain Climbers",            "Mountain Climbers"),
    "Burpees":                               ("burpee",                    "Burpees",                      "Burpees"),
    "Crunches (BW)":                         ("crunch",                    "Crunches",                     "Mekik"),
    "Beinheben (liegend)":                   ("lyingLegRaise",             "Lying Leg Raise",              "Lying Leg Raise"),
    "Sit-ups":                               ("situp",                     "Sit-Up",                       "Sit-Up"),
    "Beinstrecker liegend":                  ("lyingLegExtension",         "Lying Leg Extension",          "Lying Leg Extension"),
    "Russian Twists":                        ("russianTwist",              "Russian Twist",                "Russian Twist"),
    "Hanging Leg Raises":                    ("hangingLegRaise",           "Hanging Leg Raise",            "Hanging Leg Raise"),
    # MACHINE / CABLE · CHEST
    "Kabel Crossover":                       ("cableCrossover",            "Cable Crossover",              "Cable Crossover"),
    "Pec Deck (Butterfly)":                  ("pecDeck",                   "Pec Deck",                     "Pec Deck"),
    "Brustdrücken (Maschine)":               ("chestPressMachine",         "Machine Chest Press",          "Machine Chest Press"),
    # MACHINE / CABLE · BACK
    "Latzug (weit)":                         ("latpulldown",               "Wide-Grip Lat Pulldown",       "Wide-Grip Lat Pulldown"),
    "Latzug (eng)":                          ("latPulldownClose",          "Close-Grip Lat Pulldown",      "Close-Grip Lat Pulldown"),
    "Kabelrudern sitzend":                   ("seatedCableRow",            "Seated Cable Row",             "Seated Cable Row"),
    # MACHINE / CABLE · SHOULDERS
    "Kabel Seitheben":                       ("cableLateralRaise",         "Cable Lateral Raise",          "Cable Lateral Raise"),
    "Face Pull":                             ("facePull",                  "Face Pull",                    "Face Pull"),
    "Schulterdrücken (Maschine)":            ("shoulderPressMachine",      "Machine Shoulder Press",       "Machine Shoulder Press"),
    # MACHINE / CABLE · ARMS
    "Trizepsdrücken (Kabel)":                ("tricepPushdown",            "Cable Triceps Pushdown",       "Cable Triceps Pushdown"),
    "Trizepsstrecker über Kopf (Kabel)":     ("cableOverheadTricepExtension", "Cable Overhead Triceps Extension", "Cable Overhead Triceps Extension"),
    "Preacher Curl (Maschine)":              ("preacherCurl",              "Machine Preacher Curl",        "Machine Preacher Curl"),
    "Kabel Curl":                            ("cableCurl",                 "Cable Curl",                   "Cable Curl"),
    # MACHINE / CABLE · LEGS
    "Beinpresse":                            ("legpress",                  "Leg Press",                    "Leg Press"),
    "Beinstrecker":                          ("legExtension",              "Leg Extension",                "Leg Extension"),
    "Beinbeuger liegend":                    ("lyingLegCurl",              "Lying Leg Curl",               "Lying Leg Curl"),
    "Hack Squat":                            ("hackSquat",                 "Hack Squat",                   "Hack Squat"),
    "Smith Machine Squat":                   ("smithMachineSquat",         "Smith Machine Squat",          "Smith Machine Squat"),
    "Wadenpresse (sitzend)":                 ("seatedCalfRaise",           "Seated Calf Press",            "Seated Calf Press"),
    # MACHINE / CABLE · CORE
    "Kabel Crunch":                          ("cableCrunch",               "Cable Crunch",                 "Cable Crunch"),
    # BAND
    "Band Pull-Aparts":                      ("bandPullApart",             "Band Pull-Aparts",             "Band Pull-Aparts"),
    "Banded Squats":                         ("bandedSquat",               "Banded Squats",                "Banded Squats"),
    "Band Curls":                            ("bandCurl",                  "Band Curls",                   "Band Curls"),
    "Banded Hip Thrust":                     ("bandedHipThrust",           "Banded Hip Thrust",            "Banded Hip Thrust"),
    # KETTLEBELL
    "Kettlebell Swing":                      ("kettlebellSwing",           "Kettlebell Swing",             "Kettlebell Swing"),
    "Turkish Get-Up":                        ("turkishGetUp",              "Turkish Get-Up",               "Türk Kalkışı"),
    "Kettlebell Goblet Squat":               ("kettlebellGobletSquat",     "Kettlebell Goblet Squat",      "Kettlebell Goblet Squat"),
    "Kettlebell Snatch":                     ("kettlebellSnatch",          "Kettlebell Snatch",            "Kettlebell Snatch"),
    "Kettlebell Clean & Press":              ("kettlebellCleanAndPress",   "Kettlebell Clean & Press",     "Kettlebell Clean & Press"),
    "Kettlebell Halo":                       ("kettlebellHalo",            "Kettlebell Halo",              "Kettlebell Halo"),
    # CARDIO
    "Freier Lauf":                           ("run",                       "Outdoor Run",                  "Koşu"),
    "Laufband":                              ("treadmill",                 "Treadmill",                    "Koşu Bandı"),
    "Radfahren (outdoor)":                   ("cycling",                   "Outdoor Cycling",              "Bisiklet"),
    "Fahrradergometer":                      ("stationaryBike",            "Exercise Bike",                "Egzersiz Bisikleti"),
    "Rudermaschine":                         ("rowingMachine",             "Rowing Machine",               "Kürek Ergometresi"),
    "Crosstrainer":                          ("elliptical",                "Elliptical",                   "Eliptik"),
    "Stepper":                               ("stairStepper",              "Stair Stepper",                "Stepper"),
    "Schwimmen":                             ("swimming",                  "Swimming",                     "Yüzme"),
    # NEW DEL-116: 4 Library entries promoted from orphan ExerciseSpec.name
    "Easy Run":                              ("easyRun",                   "Easy Run",                     "Kolay Koşu"),
    "Long Run":                              ("longRun",                   "Long Run",                     "Uzun Koşu"),
    "Intervalle":                            ("intervals",                 "Intervals",                    "İnterval"),
    "Gehen / Einlaufen":                     ("warmupWalk",                "Warm-Up Walk",                 "Isınma Yürüyüşü"),
}


# Plan-Templates: id -> (suffix, de_name, en_name, tr_name)
# User-authoritative names (force-rewrite).
PROGRAMS = {
    "full_body":          ("fullBody3x",        "Ganzkörper 3x",                "Full Body 3x",                       "Tüm Vücut 3x"),
    "fat_loss_fullbody":  ("fatBurnFullBody",   "Fatburn Ganzkörper",           "Fat Loss Full Body",                 "Yağ Yakımı Tüm Vücut"),
    "home_gym_hero":      ("homeGymHero",       "Home Gym Hero",                "Home Gym Hero",                      "Home Gym Hero"),
    "bodyweight_mastery": ("bodyweightMastery", "Bodyweight Mastery",           "Bodyweight Mastery",                 "Bodyweight Mastery"),
    "push_pull_legs":     ("pushPullLegs",      "Push-Pull-Legs",               "Push-Pull-Legs",                     "Push-Pull-Legs"),
    "upper_lower":        ("upperLower",        "Upper-Lower-Split",            "Upper-Lower Split",                  "Upper-Lower Split"),
    "arnold_split":       ("arnoldSplit",       "Arnold Split",                 "Arnold Split",                       "Arnold Split"),
    "bro_split":          ("broSplit",          "Bro-Split",                    "Bro-Split",                          "Bro-Split"),
    "powerlifting_5x5":   ("powerlifting5x5",   "Powerlifting 5x5",             "Powerlifting 5x5",                   "Powerlifting 5x5"),
    "powerlifting_3x5":   ("powerlifting3x5",   "Powerlifting 3x5",             "Powerlifting 3x5",                   "Powerlifting 3x5"),
    "football_athletic":  ("footballAthletic",  "Fussball Athletik",            "Football Athletic",                  "Futbol Atletik"),
    "hybrid_beginner":    ("hybridBeginner",    "Hybrid Athlete — Beginner",    "Hybrid Athlete — Beginner",          "Hybrid Athlete — Beginner"),
    "hybrid_balanced":    ("hybridBalanced",    "Hybrid Athlete — Balanced",    "Hybrid Athlete — Balanced",          "Hybrid Athlete — Balanced"),
    "hybrid_performance": ("hybridPerformance", "Hybrid Athlete — Performance", "Hybrid Athlete — Performance",       "Hybrid Athlete — Performance"),
}


# Plan-Templates Taglines: id -> (de_tagline, en_tagline, tr_tagline)
TAGLINES = {
    "full_body":          ("3 Tage · Anfänger & Re-Einstieg",          "3 Days · Beginner & Re-Entry",                "3 Gün · Başlangıç & Yeniden Başlama"),
    "fat_loss_fullbody":  ("3 Tage · Fatburn & Kondition",             "3 Days · Fat Burn & Conditioning",            "3 Gün · Yağ Yakımı & Kondisyon"),
    "home_gym_hero":      ("3 Tage · Muskelaufbau mit Kurzhanteln",    "3 Days · Muscle Building with Dumbbells",     "3 Gün · Dambıl ile Kas Gelişimi"),
    "bodyweight_mastery": ("3 Tage · Funktionelles Training ohne Geräte", "3 Days · Functional Training, No Equipment", "3 Gün · Ekipmansız Fonksiyonel Antrenman"),
    "push_pull_legs":     ("6 Tage · Hypertrophie + Kraft",            "6 Days · Hypertrophy + Strength",             "6 Gün · Hipertrofi + Güç"),
    "upper_lower":        ("4 Tage · Kraft & Hypertrophie",            "4 Days · Strength & Hypertrophy",             "4 Gün · Güç & Hipertrofi"),
    "arnold_split":       ("6 Tage · Bodybuilding",                    "6 Days · Bodybuilding",                       "6 Gün · Vücut Geliştirme"),
    "bro_split":          ("5 Tage · Hypertrophie",                    "5 Days · Hypertrophy",                        "5 Gün · Hipertrofi"),
    "powerlifting_5x5":   ("3 Tage · Kraft & Masse",                   "3 Days · Strength & Mass",                    "3 Gün · Güç & Kütle"),
    "powerlifting_3x5":   ("3 Tage · Maximalkraft",                    "3 Days · Maximum Strength",                   "3 Gün · Maksimal Güç"),
    "football_athletic":  ("2 Tage · Kraft & Explosivität",            "2 Days · Strength & Explosiveness",           "2 Gün · Güç & Patlayıcılık"),
    "hybrid_beginner":    ("4 Tage · Kraft + Laufen Einstieg",         "4 Days · Strength + Running Intro",           "4 Gün · Güç + Koşuya Giriş"),
    "hybrid_balanced":    ("5 Tage · Kraft + Ausdauer in Balance",     "5 Days · Strength + Endurance Balanced",      "5 Gün · Güç + Dayanıklılık Dengesi"),
    "hybrid_performance": ("6 Tage · Wettkampf-Hybrid",                "6 Days · Competitive Hybrid",                 "6 Gün · Rekabetçi Hibrit"),
}


# Plan-Templates Focus: id -> (de_focus, en_focus, tr_focus)
# Generated translations (autonomous, reviewable).
FOCUS = {
    "full_body":          ("Anfänger / Allgemein",      "Beginner / General",      "Başlangıç / Genel"),
    "fat_loss_fullbody":  ("Fatburn",                   "Fat Loss",                "Yağ Yakımı"),
    "home_gym_hero":      ("Hypertrophie",              "Hypertrophy",             "Hipertrofi"),
    "bodyweight_mastery": ("Funktionelle Fitness",      "Functional Fitness",      "Fonksiyonel Fitness"),
    "push_pull_legs":     ("Hypertrophie",              "Hypertrophy",             "Hipertrofi"),
    "upper_lower":        ("Kraft + Hypertrophie",      "Strength + Hypertrophy",  "Güç + Hipertrofi"),
    "arnold_split":       ("Hypertrophie",              "Hypertrophy",             "Hipertrofi"),
    "bro_split":          ("Hypertrophie",              "Hypertrophy",             "Hipertrofi"),
    "powerlifting_5x5":   ("Kraft",                     "Strength",                "Güç"),
    "powerlifting_3x5":   ("Kraft",                     "Strength",                "Güç"),
    "football_athletic":  ("Athletik",                  "Athletics",               "Atletik"),
    "hybrid_beginner":    ("Hybrid & Athletik",         "Hybrid & Athletics",      "Hibrit & Atletik"),
    "hybrid_balanced":    ("Hybrid & Athletik",         "Hybrid & Athletics",      "Hibrit & Atletik"),
    "hybrid_performance": ("Hybrid & Athletik",         "Hybrid & Athletics",      "Hibrit & Atletik"),
}


# Plan-Templates Description: id -> (de, en, tr)
# Generated translations (autonomous, reviewable).
DESCRIPTIONS = {
    "full_body": (
        "Höchste Trainingsfrequenz pro Muskelgruppe. Laut Forschung optimal für Anfänger und Wiedereinstieg — maximales Signal für Muskelwachstum.",
        "Highest training frequency per muscle group. Research-backed as optimal for beginners and re-entry — maximum signal for muscle growth.",
        "Kas grubu başına en yüksek antrenman frekansı. Araştırmalar başlangıç ve yeniden başlama için ideal olduğunu gösteriyor — kas gelişimi için maksimum sinyal.",
    ),
    "fat_loss_fullbody": (
        "Effektiver Ganzkörperplan für maximalen Kalorienverbrauch. Kurze Pausen (60s) halten die Herzfrequenz oben — kombiniert mit einem Cardio-Finisher am Ende jeder Einheit.",
        "Effective full-body plan for maximum calorie burn. Short rest periods (60s) keep heart rate elevated — combined with a cardio finisher at the end of each session.",
        "Maksimum kalori yakımı için etkili tüm vücut planı. Kısa molalar (60s) kalp atış hızını yüksek tutar — her seansın sonunda kardiyo finisher ile birleştirilir.",
    ),
    "home_gym_hero": (
        "Effektiver Ganzkörperplan komplett mit Kurzhanteln. Ideal für das Training zuhause — kein Fitnessstudio nötig.",
        "Effective full-body plan using only dumbbells. Ideal for training at home — no gym required.",
        "Sadece dambıllarla etkili tüm vücut planı. Evde antrenman için ideal — salon gerekmez.",
    ),
    "bodyweight_mastery": (
        "Komplettes Körpergewichtstraining ohne ein einziges Gerät. Kürzere Pausen und isometrische Übungen sorgen für maximalen Trainingsreiz.",
        "Complete bodyweight training without a single piece of equipment. Shorter rest periods and isometric exercises maximize training stimulus.",
        "Tek bir ekipman olmadan komple vücut ağırlığı antrenmanı. Kısa molalar ve izometrik hareketler maksimum antrenman uyarısı sağlar.",
    ),
    "push_pull_legs": (
        "Wissenschaftlich optimierter Split. Jede Muskelgruppe wird 2x pro Woche trainiert – ideal für intermediäre Sportler laut Meta-Analysen.",
        "Scientifically optimized split. Each muscle group trained 2x per week — ideal for intermediate lifters per meta-analyses.",
        "Bilimsel olarak optimize edilmiş split. Her kas grubu haftada 2 kez çalıştırılır — meta-analizlere göre orta seviye sporcular için ideal.",
    ),
    "upper_lower": (
        "Optimale Balance zwischen Frequenz und Volumen. Laut Studienlage der effektivste Split für Kraft- und Muskelaufbau bei Intermediären.",
        "Optimal balance between frequency and volume. Studies show this is the most effective split for strength and muscle building at the intermediate level.",
        "Frekans ve hacim arasında optimal denge. Çalışmalar bunun orta seviyede güç ve kas gelişimi için en etkili split olduğunu gösteriyor.",
    ),
    "arnold_split": (
        "Arnold Schwarzeneggers Trainingsansatz: Antagonisten (Brust+Rücken) werden gemeinsam trainiert für maximalen Pump und Dichte.",
        "Arnold Schwarzenegger's training approach: antagonist muscles (chest + back) are trained together for maximum pump and density.",
        "Arnold Schwarzenegger'in antrenman yaklaşımı: antagonist kaslar (göğüs + sırt) maksimum pump ve yoğunluk için birlikte çalıştırılır.",
    ),
    "bro_split": (
        "Klassischer Bodybuilding-Split mit hohem Volumen pro Muskelgruppe. Jede Muskelgruppe wird einmal pro Woche mit maximaler Erschöpfung trainiert.",
        "Classic bodybuilding split with high volume per muscle group. Each muscle group is trained once per week to maximum exhaustion.",
        "Kas grubu başına yüksek hacimli klasik vücut geliştirme bölünmesi. Her kas grubu haftada bir kez maksimum yorgunluğa kadar çalıştırılır.",
    ),
    "powerlifting_5x5": (
        "Das bewährteste Kraft-Programm für Anfänger & Fortgeschrittene. Progressive Überlastung mit den Grundübungen — wissenschaftlich und praktisch belegt.",
        "The most proven strength program for beginners and intermediates. Progressive overload with the main lifts — scientifically and practically validated.",
        "Başlangıç ve orta seviye için en kanıtlanmış güç programı. Temel hareketlerle aşamalı yüklenme — bilimsel ve pratik olarak doğrulanmış.",
    ),
    "powerlifting_3x5": (
        "Dreier-Frequenz auf die Grundübungen Kniebeuge, Bankdrücken und Kreuzheben. Jede Session dreht sich um eine primäre Wettkampfübung mit schweren 3x5-Sätzen.",
        "Triple frequency on the core lifts: squat, bench press, and deadlift. Each session focuses on one primary competition lift with heavy 3x5 sets.",
        "Temel hareketler (squat, bench press, deadlift) için üçlü frekans. Her seans ağır 3x5 setleriyle bir ana yarışma hareketine odaklanır.",
    ),
    "football_athletic": (
        "Athletik-Programm für Mannschaftssportler: Maximalkraft und Schnellkraft in zwei kompakten Einheiten pro Woche — ideal als Ergänzung zum Vereinstraining.",
        "Athletics program for team-sport athletes: maximum strength and power in two compact sessions per week — ideal as a complement to club training.",
        "Takım sporcuları için atletik program: haftada iki kompakt seansta maksimum güç ve patlayıcı kuvvet — kulüp antrenmanına ideal tamamlayıcı.",
    ),
    "hybrid_beginner": (
        "Concurrent-Training light: zwei Ganzkörper-Strength-Einheiten + zwei lockere Lauf-Tage pro Woche. RIR-Puffer schützt den Laufmotor, kein zerstörendes Versagens-Training.",
        "Concurrent training light: two full-body strength sessions + two easy run days per week. RIR buffer protects the running engine — no destructive failure training.",
        "Hafif eşzamanlı antrenman: haftada iki tüm vücut güç seansı + iki kolay koşu günü. RIR tamponu koşu motorunu korur — yıkıcı başarısızlık antrenmanı yok.",
    ),
    "hybrid_balanced": (
        "Drei fokussierte Strength-Einheiten (Push/Pull/Legs-Light) plus zwei strategisch platzierte Lauf-Tage. RIR-Puffer 2–3 verhindert systemische Erschöpfung — bleibt Trainings-vertrāglich.",
        "Three focused strength sessions (Push/Pull/Legs-Light) plus two strategically placed run days. RIR buffer of 2–3 prevents systemic fatigue — stays training-compatible.",
        "Üç odaklı güç seansı (Push/Pull/Hafif Bacak) artı iki stratejik konumlandırılmış koşu günü. RIR tamponu 2–3 sistemik yorgunluğu önler — antrenmana uyumlu kalır.",
    ),
    "hybrid_performance": (
        "Sechs Trainingstage: drei Strength-Einheiten (Push/Pull/Legs) + drei Läufe (Easy, Intervalle, Long Run). Strength-RIR konservativ 2.5, damit der Gesamt-Volumen-Stress trainings-vertraglich bleibt.",
        "Six training days: three strength sessions (Push/Pull/Legs) + three runs (Easy, Intervals, Long Run). Conservative RIR of 2.5 on strength to keep total volume stress training-compatible.",
        "Altı antrenman günü: üç güç seansı (Push/Pull/Bacak) + üç koşu (Kolay, İnterval, Uzun Koşu). Toplam hacim stresinin antrenmana uyumlu kalması için güçte ihtiyatlı RIR 2.5.",
    ),
}


# ─────────────────────────────────────────────────────────────────────
# xcstrings patch  —  FORCE-rewrite EN+TR (overwrite existing values)
# DE values are only written if missing (DE = source of truth in source).
# ─────────────────────────────────────────────────────────────────────

def force_upsert(strings, key, de, en, tr, *, force_en=True, force_tr=True, force_de=False):
    """Set DE/EN/TR for a key. Force-overwrites EN/TR by default."""
    if key not in strings:
        strings[key] = {"extractionState": "manual", "localizations": {}}
        created = True
    else:
        created = False
    entry = strings[key].setdefault("localizations", {})
    changed = 0
    # DE (only fill if missing)
    if de is not None:
        existing = entry.get("de", {}).get("stringUnit", {}).get("value")
        if force_de or not existing:
            if existing != de:
                entry["de"] = {"stringUnit": {"state": "translated", "value": de}}
                changed += 1
    # EN
    if en is not None:
        existing = entry.get("en", {}).get("stringUnit", {}).get("value")
        if force_en or not existing:
            if existing != en:
                entry["en"] = {"stringUnit": {"state": "translated", "value": en}}
                changed += 1
    # TR
    if tr is not None:
        existing = entry.get("tr", {}).get("stringUnit", {}).get("value")
        if force_tr or not existing:
            if existing != tr:
                entry["tr"] = {"stringUnit": {"state": "translated", "value": tr}}
                changed += 1
    return created, changed


def patch_xcstrings():
    with open(XCSTRINGS, "r", encoding="utf-8") as f:
        data = json.load(f)
    strings = data["strings"]

    created = changed = 0

    # 1) Exercise names
    for de_name, (suffix, en, tr) in EXERCISES.items():
        c, ch = force_upsert(strings, f"exercise.name.{suffix}", de_name, en, tr, force_de=True)
        created += int(c)
        changed += ch

    # 2) Plan names
    for pid, (suffix, de, en, tr) in PROGRAMS.items():
        c, ch = force_upsert(strings, f"plan.template.{suffix}", de, en, tr, force_de=True)
        created += int(c)
        changed += ch

    # 3) Plan taglines
    for pid, (de, en, tr) in TAGLINES.items():
        suffix = PROGRAMS[pid][0]
        c, ch = force_upsert(strings, f"plan.template.{suffix}.tagline", de, en, tr, force_de=True)
        created += int(c)
        changed += ch

    # 4) Plan focus
    for pid, (de, en, tr) in FOCUS.items():
        suffix = PROGRAMS[pid][0]
        c, ch = force_upsert(strings, f"plan.template.{suffix}.focus", de, en, tr, force_de=True)
        created += int(c)
        changed += ch

    # 5) Plan descriptions
    for pid, (de, en, tr) in DESCRIPTIONS.items():
        suffix = PROGRAMS[pid][0]
        c, ch = force_upsert(strings, f"plan.template.{suffix}.description", de, en, tr, force_de=True)
        created += int(c)
        changed += ch

    with open(XCSTRINGS, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"xcstrings: {created} new keys, {changed} translation slots rewritten")


# ─────────────────────────────────────────────────────────────────────
# Library — ensure the 4 new Orphan-derived Library entries exist.
# ─────────────────────────────────────────────────────────────────────

NEW_LIBRARY_ENTRIES_BLOCK = """
        // ── CARDIO · HYBRID-PLAN-LIFTS (DEL-116) ───────────────────────────
        // DEL-116: Promoted aus den ProgramTemplates-Orphans. Vorher waren
        // "Easy Run", "Long Run", "Intervalle", "Gehen / Einlaufen" inline
        // ExerciseSpec(name:) Strings in Hybrid-Plan-Templates ohne Library-
        // Match — landeten als rohes DE in Exercise.name. Jetzt offiziell
        // im Catalog mit Multi-Locale-Display.
        ExerciseTemplateSpec(name: "Easy Run",                         equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.40, cnsDemandFactor: 0.25, axialLoadFactor: 0.20, technicalComplexityFactor: 0.10, recoveryClass: .medium,
                             localizationKey: "exercise.name.easyRun"),
        ExerciseTemplateSpec(name: "Long Run",                         equipment: .bodyweight, primaryMuscle: .core,      isCardio: true,
                             systemicFatigueFactor: 0.70, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.35, axialLoadFactor: 0.25, technicalComplexityFactor: 0.10, recoveryClass: .high,
                             localizationKey: "exercise.name.longRun"),
        ExerciseTemplateSpec(name: "Intervalle",                       equipment: .bodyweight, primaryMuscle: .core,      isCardio: true,
                             systemicFatigueFactor: 0.75, localMuscleDamageFactor: 0.50, cnsDemandFactor: 0.55, axialLoadFactor: 0.20, technicalComplexityFactor: 0.20, recoveryClass: .high,
                             localizationKey: "exercise.name.intervals"),
        ExerciseTemplateSpec(name: "Gehen / Einlaufen",                equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.15, localMuscleDamageFactor: 0.10, cnsDemandFactor: 0.05, axialLoadFactor: 0.05, technicalComplexityFactor: 0.05, recoveryClass: .low,
                             localizationKey: "exercise.name.warmupWalk"),
"""


def patch_library():
    """Insert the 4 new Library entries before the closing `]` of `Self.all`.
    Idempotent: skips if already inserted (marker comment present)."""
    with open(LIBRARY_FILE, "r", encoding="utf-8") as f:
        text = f.read()
    if "CARDIO · HYBRID-PLAN-LIFTS (DEL-116)" in text:
        print("library: DEL-116 entries already present")
        return
    # Find the closing `]` of `public static let all: [...] = [`. The last
    # `Spec(...)` entry ends with `)`. We look for the pattern `\n    ]` after
    # the all-array opening, but the file has many `]` — easier: find the
    # ` recoveryClass: .medium)\n    ]\n` style; but safer to find the
    # specific anchor "Schwimmen" entry (last library entry) and insert AFTER it.
    anchor = '"Schwimmen"'
    idx = text.rfind(anchor)
    if idx < 0:
        print("ERROR: couldn't find 'Schwimmen' anchor in library")
        sys.exit(1)
    # Walk to end of that Spec(...) — count parens
    spec_start = text.rfind("ExerciseTemplateSpec(", 0, idx)
    if spec_start < 0:
        print("ERROR: couldn't locate Schwimmen spec start")
        sys.exit(1)
    # Balance parens
    depth = 0
    in_string = False
    j = spec_start
    while j < len(text):
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
    insert_at = j + 1   # after the closing `)`
    # Remove any trailing comma/whitespace before inserting our block — the
    # current state has no comma after Schwimmen.  Add a comma + newline.
    new_text = text[:insert_at] + "," + NEW_LIBRARY_ENTRIES_BLOCK.rstrip() + text[insert_at:]
    with open(LIBRARY_FILE, "w", encoding="utf-8") as f:
        f.write(new_text)
    print("library: inserted 4 new DEL-116 entries")


# ─────────────────────────────────────────────────────────────────────
# Programs — strip "Cardio / " prefix where present (matches Library entries)
# ─────────────────────────────────────────────────────────────────────

ORPHAN_PREFIX_RENAMES = {
    '"Cardio / Laufband"':         '"Laufband"',
    '"Cardio / Fahrradergometer"': '"Fahrradergometer"',
    '"Cardio / Stepper"':          '"Stepper"',
}


def patch_programs():
    with open(PROGRAMS_FILE, "r", encoding="utf-8") as f:
        text = f.read()
    count = 0
    for old, new in ORPHAN_PREFIX_RENAMES.items():
        new_text, n = text.replace(old, new), text.count(old)
        if n:
            text = new_text
            count += n
    with open(PROGRAMS_FILE, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"programs: stripped 'Cardio / ' prefix in {count} ExerciseSpec literals")


# ─────────────────────────────────────────────────────────────────────
# Patch del113 script — keep its EXERCISES + PROGRAMS dicts in sync
# ─────────────────────────────────────────────────────────────────────

def patch_del113_script():
    DEL113 = os.path.join(ROOT, ".scripts", "del113_localize_library.py")
    with open(DEL113, "r", encoding="utf-8") as f:
        text = f.read()
    # We won't surgically edit those huge dicts here — del116 is now the
    # canonical source-of-truth for translations. Just add a header marker
    # so a future maintainer knows where to look.
    marker = "# NOTE: After DEL-116, the canonical EXERCISES + PROGRAMS dicts"
    if marker in text:
        return
    insert_at = text.find('"""DEL-113') + len('"""DEL-113 — Full Library Translation.\n\n')
    if insert_at <= 0:
        print("WARN: del113 docstring marker not found — skipping")
        return
    note = ("# NOTE: After DEL-116, the canonical EXERCISES + PROGRAMS dicts\n"
            "# moved to .scripts/del116_authoritative_translations.py. This\n"
            "# script's dicts may carry pre-DEL-116 values for new annotations\n"
            "# only; the xcstrings catalog values are owned by del116.\n\n")
    text = text[:insert_at] + note + text[insert_at:]
    with open(DEL113, "w", encoding="utf-8") as f:
        f.write(text)
    print("del113 script: header note added")


# ─────────────────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("DEL-116: Authoritative Translation Refresh")
    print("=" * 60)
    patch_library()       # do this BEFORE xcstrings, so new exercise.name keys are valid
    print()
    patch_programs()
    print()
    patch_xcstrings()
    print()
    patch_del113_script()
    print()
    print("Done.")


if __name__ == "__main__":
    main()
