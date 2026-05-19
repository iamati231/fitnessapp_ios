"""DEL-114 -- Naming Convention Sweep.

Renames the raw German `name:` strings of Library entries to follow the
DEL-114 naming convention:
    * Equipment goes at the END inside parens: (KH), (LH), (Kabel),
      (Maschine), (Multipresse), (SZ). (BW) is allowed as an exception
      because removing it would collide with the barbell-default variants.
    * Drop leading "KH-" / "Langhantel " prefixes; convert to suffix.
    * "Trizep" -> "Trizeps" (grammar) and remove Denglisch where there is
      a clear German Gym-Begriff.
    * International Gym-Loanwords (Hammer Curl, Skull Crusher, Goblet Squat,
      Push Press, Pendlay Row, Burpees, Plank, ...) bleiben unangetastet.

Touches:
    1. Sources/FitnessAppCore/Programs/ExerciseLibraryData.swift
       - rename in `Self.all` definitions
       - rename in `Self.alternatives` dictionary keys AND values
    2. Sources/FitnessAppCore/Programs/ProgramTemplates.swift
       - rename in ExerciseSpec(name: "...") literals
    3. Sources/FitnessAppUI/Resources/Localizable.xcstrings
       - rewrite the `de` stringUnit value for each renamed entry's
         corresponding `exercise.name.*` key
    4. .scripts/del113_localize_library.py
       - rewrite the EXERCISES dict keys (the script's source of truth for
         future runs) so subsequent `validate()` passes match the new names.

Idempotent: re-running produces no diff after the first successful run.

Run from project root:
    "C:\\Python314\\python.exe" .scripts/del114_normalize_names.py
"""
import json
import os
import re
import sys

ROOT          = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
XCSTRINGS     = os.path.join(ROOT, "Sources", "FitnessAppUI", "Resources", "Localizable.xcstrings")
LIBRARY_FILE  = os.path.join(ROOT, "Sources", "FitnessAppCore", "Programs", "ExerciseLibraryData.swift")
PROGRAMS_FILE = os.path.join(ROOT, "Sources", "FitnessAppCore", "Programs", "ProgramTemplates.swift")
DEL113_SCRIPT = os.path.join(ROOT, ".scripts", "del113_localize_library.py")


# Renames: old German name -> new German name following the DEL-114 convention.
#
# The localizationKey on each affected entry stays the SAME (it's an opaque
# identifier). Only the human-readable DE display string changes — both in
# the Swift source AND in the xcstrings `de` stringUnit value.
RENAMES = {
    # KH- prefix → (KH) suffix
    "KH-Bankdrücken":                       "Bankdrücken (KH)",
    "KH-Schrägbankdrücken (aufwärts)":      "Schrägbankdrücken aufwärts (KH)",
    "KH-Flyes (flach)":                     "Flyes flach (KH)",
    "KH-Flyes (Schrägbank)":                "Flyes Schrägbank (KH)",
    "KH-Rudern einarmig":                   "Rudern einarmig (KH)",
    "KH-Pullover":                          "Pullover (KH)",
    "KH-Schulterdrücken":                   "Schulterdrücken (KH)",
    "KH-Shrug":                             "Shrug (KH)",
    "KH-Ausfallschritte":                   "Ausfallschritte (KH)",
    "KH-Romanian Deadlift":                 "Rumänisches Kreuzheben (KH)",
    "KH-Hip Thrust":                        "Hip Thrust (KH)",
    "KH-Wadenheben":                        "Wadenheben (KH)",
    "KH-Curl":                              "Bizeps-Curl (KH)",
    "KH Overhead Trizep Extension":         "Trizepsstrecker über Kopf (KH)",

    # Langhantel prefix → (LH) suffix
    "Langhantel Curl":                      "Bizeps-Curl (LH)",
    "Langhantel Shrug":                     "Shrug (LH)",

    # Trizep -> Trizeps + Denglisch removal where a German term exists
    "Trizep Pushdown (Kabel)":              "Trizepsdrücken (Kabel)",
    "Overhead Trizep Extension (Kabel)":    "Trizepsstrecker über Kopf (Kabel)",
    "Trizep Kickback (KH)":                 "Trizepskickback (KH)",

    # Maschine-naming normalization (suffix-only, drop hyphen forms)
    "Brust-Drückmaschine":                  "Brustdrücken (Maschine)",
    "Schulterdrück-Maschine":               "Schulterdrücken (Maschine)",

    # Implicit-equipment Curls -> explicit (KH)
    "Schrägbank Curl":                      "Schrägbank-Curl (KH)",
    "Konzentrations Curl":                  "Konzentrations-Curl (KH)",
}


def assert_no_collisions():
    """Targets must be unique and must not collide with names that are
    already in the library and NOT being renamed."""
    targets = list(RENAMES.values())
    if len(set(targets)) != len(targets):
        seen = set()
        dups = []
        for t in targets:
            if t in seen:
                dups.append(t)
            seen.add(t)
        print("ERROR: rename targets collide:", dups)
        sys.exit(1)

    # Sanity: targets must not match any source name (no rename should
    # produce a name that's still in the OLD set)
    overlap = set(RENAMES.values()) & set(RENAMES.keys())
    if overlap:
        print("ERROR: rename target overlaps with source:", overlap)
        sys.exit(1)


def patch_file_text(path, transform):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    new_text, count = transform(text)
    if new_text == text:
        return 0
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_text)
    return count


def rename_in_string_literals(text):
    """Rewrite every Swift string literal `"<old>"` to `"<new>"` for every
    entry in RENAMES. Returns (new_text, count_of_replacements)."""
    count = 0
    for old, new in RENAMES.items():
        # Match the exact string-literal occurrence (between double-quotes).
        # We rely on the assumption that the renamed names do not appear as
        # substrings inside other strings — true for the library + templates.
        pattern = '"' + re.escape(old) + '"'
        replacement = '"' + new + '"'
        new_text, n = re.subn(pattern, replacement, text)
        if n:
            text = new_text
            count += n
    return text, count


def patch_library():
    n = patch_file_text(LIBRARY_FILE, rename_in_string_literals)
    print(f"library: {n} string-literal renames")


def patch_programs():
    n = patch_file_text(PROGRAMS_FILE, rename_in_string_literals)
    print(f"programs: {n} string-literal renames")


def patch_xcstrings():
    """Rewrite the `de` stringUnit value where the catalog entry's current
    DE matches an OLD RENAME key. Conservative — only touches DE; leaves EN
    and TR alone."""
    with open(XCSTRINGS, "r", encoding="utf-8") as f:
        data = json.load(f)

    updated = 0
    for key, entry in data["strings"].items():
        if not key.startswith("exercise.name."):
            continue
        locs = entry.get("localizations", {})
        de_unit = locs.get("de", {}).get("stringUnit", {})
        current_de = de_unit.get("value")
        if current_de and current_de in RENAMES:
            de_unit["value"] = RENAMES[current_de]
            de_unit["state"] = "translated"
            updated += 1

    if updated:
        with open(XCSTRINGS, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
    print(f"xcstrings: updated {updated} DE values")


def patch_del113_script():
    """Rewrite the EXERCISES dict keys in del113_localize_library.py so the
    validator stays canonical. We do this by simple `"<old>"` -> `"<new>"`
    replacement, scoped to the EXERCISES block."""
    with open(DEL113_SCRIPT, "r", encoding="utf-8") as f:
        text = f.read()

    # Locate the EXERCISES dict block
    start = text.find("EXERCISES = {")
    end = text.find("}\n\n\n# ", start)  # blank-line separator before next top-level
    if start < 0 or end < 0:
        print("WARN: couldn't locate EXERCISES block in del113 script — skipping")
        return

    block = text[start:end]
    new_block = block
    count = 0
    for old, new in RENAMES.items():
        pattern = '"' + re.escape(old) + '"'
        replacement = '"' + new + '"'
        new_block, n = re.subn(pattern, replacement, new_block)
        count += n

    if count == 0:
        print("del113 script: no renames needed in EXERCISES dict")
        return

    text = text[:start] + new_block + text[end:]
    with open(DEL113_SCRIPT, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"del113 script: {count} key renames in EXERCISES dict")


def main():
    print("=" * 60)
    print("DEL-114: Naming Convention Sweep")
    print("=" * 60)
    assert_no_collisions()
    print(f"Renames defined: {len(RENAMES)}")
    print()
    print("-> ExerciseLibraryData.swift")
    patch_library()
    print()
    print("-> ProgramTemplates.swift")
    patch_programs()
    print()
    print("-> Localizable.xcstrings")
    patch_xcstrings()
    print()
    print("-> del113_localize_library.py")
    patch_del113_script()
    print()
    print("Done.")


if __name__ == "__main__":
    main()
