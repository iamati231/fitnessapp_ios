"""Generiert ExerciseSecondaryMuscles.swift aus exercises.json und exercise_gif_overrides.json.

Matching via GIF-Dateiname (gemeinsamer Schlüssel):
  overrides.json:  "Kreuzheben (konventionell)" -> "0032-ila4NZS.gif"
  exercises.json:  gif_url = "videos/0032-ila4NZS.gif"

Lauf:
    py .scripts/build_secondary_muscles.py <pfad/zu/exercises.json>
"""

import json
import os
import re
import sys
import unicodedata

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OVERRIDES_JSON = os.path.join(ROOT, "exercise_gif_overrides.json")
OUT_SWIFT = os.path.join(ROOT, "Sources", "DeltiqCore", "Exercises", "ExerciseSecondaryMuscles.swift")

# Vereinfachtes Mapping JSON-String -> MuscleGroup Swift-Case
MUSCLE_MAP = {
    "back":               "back",
    "lower back":         "back",
    "upper back":         "back",
    "middle back":        "back",
    "lats":               "back",
    "rhomboids":          "back",
    "traps":              "back",
    "neck":               "back",
    "hamstrings":         "hamstrings",
    "glutes":             "glutes",
    "biceps":             "biceps",
    "forearms":           "biceps",
    "wrist flexors":      "biceps",
    "triceps":            "triceps",
    "shoulders":          "shoulders",
    "chest":              "chest",
    "pectorals":          "chest",
    "core":               "core",
    "abs":                "core",
    "obliques":           "core",
    "hip flexors":        "core",
    "serratus anterior":  "core",
    "quadriceps":         "quads",
    "quads":              "quads",
    "adductors":          "quads",
    "abductors":          "quads",
    "calves":             "calves",
    "ankle stabilizers":  "calves",
}

def normalize(name: str) -> str:
    """Gleiche Normalisierung wie ExerciseMediaProvider.normalizedKey(for:) in Swift."""
    nfkd = unicodedata.normalize("NFKD", name)
    ascii_str = nfkd.encode("ascii", "ignore").decode("ascii")
    ascii_str = ascii_str.replace("ss", "ss")  # ß wurde via NFKD zu 's' + combining — ß muss vorher ersetzt werden
    # ß wird durch NFKD NICHT zu ss — separat ersetzen
    name2 = name.replace("ß", "ss")
    nfkd2 = unicodedata.normalize("NFKD", name2)
    ascii_str = nfkd2.encode("ascii", "ignore").decode("ascii")
    ascii_str = re.sub(r"[^a-z0-9 ]", " ", ascii_str.lower())
    return re.sub(r" +", " ", ascii_str).strip()

def map_muscles(muscles: list) -> list:
    result = []
    seen = set()
    for m in muscles:
        mapped = MUSCLE_MAP.get(m.lower().strip())
        if mapped and mapped not in seen:
            result.append(mapped)
            seen.add(mapped)
    return result

def main():
    if len(sys.argv) < 2:
        print("Usage: py build_secondary_muscles.py <exercises.json>")
        sys.exit(1)

    exercises_path = sys.argv[1]
    print(f"Lese {exercises_path} ...")
    with open(exercises_path, encoding="utf-8") as f:
        exercises = json.load(f)

    print(f"Lese {OVERRIDES_JSON} ...")
    with open(OVERRIDES_JSON, encoding="utf-8-sig") as f:
        overrides = json.load(f)

    # gif_filename -> secondary_muscles
    gif_to_secondary: dict[str, list[str]] = {}
    for ex in exercises:
        gif_url = ex.get("gif_url", "")
        if not gif_url:
            continue
        gif_file = os.path.basename(gif_url)  # "videos/0032-ila4NZS.gif" -> "0032-ila4NZS.gif"
        sec = ex.get("secondary_muscles", [])
        if sec:
            gif_to_secondary[gif_file] = sec

    # German exercise name -> secondary MuscleGroup cases
    entries: list[tuple[str, list[str]]] = []
    matched = 0
    for de_name, gif_file in overrides.items():
        sec_raw = gif_to_secondary.get(gif_file, [])
        if not sec_raw:
            continue
        mapped = map_muscles(sec_raw)
        if not mapped:
            continue
        norm = normalize(de_name)
        entries.append((norm, mapped))
        matched += 1

    entries.sort(key=lambda x: x[0])
    print(f"Gematchte Einträge mit Secondary Muscles: {matched}/{len(overrides)}")

    lines = [
        "// Generiert von .scripts/build_secondary_muscles.py — nicht von Hand editieren.",
        "",
        "public enum ExerciseSecondaryMuscles {",
        "    public static let byNormalizedName: [String: [MuscleGroup]] = Dictionary(",
        "        uniqueKeysWithValues: [",
    ]
    for norm, muscles in entries:
        muscle_list = ", ".join(f".{m}" for m in muscles)
        lines.append(f'            ("{norm}", [{muscle_list}]),')
    lines[-1] = lines[-1].rstrip(",")  # letztes Komma entfernen
    lines += [
        "        ]",
        "    )",
        "}",
        "",
    ]

    with open(OUT_SWIFT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"Geschrieben: {OUT_SWIFT}")

if __name__ == "__main__":
    main()
