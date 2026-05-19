"""DEL-121 #5 — Final root-cause fix for Codemagic / Xcode 26.4.1's
GenerateStringSymbols step.

Apple's symbol generator processes dot-namespaced keys as nested Swift
structs/enums. A key like `plan.template.arnoldSplit` becomes a String
constant at the leaf position. But when ANOTHER key in the same catalog
is `plan.template.arnoldSplit.tagline`, the generator needs the SAME
name `arnoldSplit` to act as a parent NAMESPACE containing `tagline`.

Same Swift identifier can't be BOTH a String constant AND a parent
struct/enum. The generator gives up and the build fails.

This script:
  1. Finds all such parent-leaf collision pairs in the catalog.
  2. Renames each leaf key by appending a semantic suffix
     (`.name` / `.label` / `.title` / `.button`).
  3. Rewrites all Swift source files to use the new key.
  4. Validates afterwards: no collisions remain.

Idempotent: re-running produces no diff after the first pass.

Run from project root:
    "C:\\Python314\\python.exe" .scripts/del121_fix_parent_leaf_collisions.py
"""
import json
import os
import re
import sys

ROOT      = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
XCSTRINGS = os.path.join(ROOT, "Sources", "FitnessAppUI", "Resources", "Localizable.xcstrings")
SOURCES   = os.path.join(ROOT, "Sources")
SCRIPTS   = os.path.join(ROOT, ".scripts")

# Manual mapping: leaf-key -> new-leaf-key.
# Suffix chosen per semantic class:
#   .name   -> proper nouns (plan-templates)
#   .label  -> short field labels, picker options
#   .title  -> section/screen headers
#   .button -> button text
RENAMES = {
    # plan-templates (14)
    "plan.template.arnoldSplit":       "plan.template.arnoldSplit.name",
    "plan.template.bodyweightMastery": "plan.template.bodyweightMastery.name",
    "plan.template.broSplit":          "plan.template.broSplit.name",
    "plan.template.fatBurnFullBody":   "plan.template.fatBurnFullBody.name",
    "plan.template.footballAthletic":  "plan.template.footballAthletic.name",
    "plan.template.fullBody3x":        "plan.template.fullBody3x.name",
    "plan.template.homeGymHero":       "plan.template.homeGymHero.name",
    "plan.template.hybridBalanced":    "plan.template.hybridBalanced.name",
    "plan.template.hybridBeginner":    "plan.template.hybridBeginner.name",
    "plan.template.hybridPerformance": "plan.template.hybridPerformance.name",
    "plan.template.powerlifting3x5":   "plan.template.powerlifting3x5.name",
    "plan.template.powerlifting5x5":   "plan.template.powerlifting5x5.name",
    "plan.template.pushPullLegs":      "plan.template.pushPullLegs.name",
    "plan.template.upperLower":        "plan.template.upperLower.name",

    # activity (5)
    "activity.active":     "activity.active.label",
    "activity.light":      "activity.light.label",
    "activity.moderate":   "activity.moderate.label",
    "activity.sedentary":  "activity.sedentary.label",
    "activity.veryActive": "activity.veryActive.label",

    # coaching.tone (3)
    "coaching.tone.analytical": "coaching.tone.analytical.label",
    "coaching.tone.motivating": "coaching.tone.motivating.label",
    "coaching.tone.strict":     "coaching.tone.strict.label",

    # coaching.goal (3)
    "coaching.goal.hybrid":      "coaching.goal.hybrid.label",
    "coaching.goal.hypertrophy": "coaching.goal.hypertrophy.label",
    "coaching.goal.strength":    "coaching.goal.strength.label",

    # dashboard.plan (3)
    "dashboard.plan.checkoffRestDay": "dashboard.plan.checkoffRestDay.button",
    "dashboard.plan.noActivePlan":    "dashboard.plan.noActivePlan.title",
    "dashboard.plan.planEmpty":       "dashboard.plan.planEmpty.title",

    # dashboardSettings (3)
    "dashboardSettings.entry":             "dashboardSettings.entry.title",
    "dashboardSettings.section.active":    "dashboardSettings.section.active.title",
    "dashboardSettings.section.inactive":  "dashboardSettings.section.inactive.title",

    # day editor (2)
    "day.editor.start":     "day.editor.start.button",
    "day.restDay.complete": "day.restDay.complete.button",

    # measurement (7)
    "measurement.derived.navy":         "measurement.derived.navy.label",
    "measurement.field.shoulder":       "measurement.field.shoulder.label",
    "measurement.profile.age":          "measurement.profile.age.label",
    "measurement.profile.sex":          "measurement.profile.sex.label",
    "measurement.section.additional":   "measurement.section.additional.title",
    "measurement.section.core":         "measurement.section.core.title",

    # calc.plate (1)
    "calc.plate.unit": "calc.plate.unit.label",

    # settings.preferences (1)
    "settings.preferences.units": "settings.preferences.units.label",
}


def patch_xcstrings():
    with open(XCSTRINGS, "r", encoding="utf-8") as f:
        d = json.load(f)
    renamed = 0
    for old, new in RENAMES.items():
        if old in d["strings"]:
            if new in d["strings"]:
                print(f"WARN: target {new!r} already exists, skipping")
                continue
            d["strings"][new] = d["strings"].pop(old)
            renamed += 1
    with open(XCSTRINGS, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"xcstrings: {renamed} keys renamed")


def patch_swift_sources():
    files_changed = 0
    total_replacements = 0
    for dirpath, _, files in os.walk(SOURCES):
        for fn in files:
            if not fn.endswith(".swift"):
                continue
            p = os.path.join(dirpath, fn)
            with open(p, "r", encoding="utf-8") as f:
                text = f.read()
            orig = text
            for old, new in RENAMES.items():
                # Match the exact string literal, ignoring partial matches
                # like `plan.template.arnoldSplit.tagline` (which contains
                # `plan.template.arnoldSplit` as a substring).
                old_lit = f'"{old}"'
                new_lit = f'"{new}"'
                # Count matches to track replacements
                count = text.count(old_lit)
                if count:
                    text = text.replace(old_lit, new_lit)
                    total_replacements += count
            if text != orig:
                with open(p, "w", encoding="utf-8") as f:
                    f.write(text)
                files_changed += 1
    print(f"Swift sources: {files_changed} files updated, {total_replacements} key references rewritten")


def patch_scripts():
    """Keep the del116 + del117 script dicts in sync for future runs."""
    for fn in ("del116_authoritative_translations.py",
               "del117_hardcoded_sweep.py",
               "del116_patch_templates.py"):
        p = os.path.join(SCRIPTS, fn)
        if not os.path.exists(p):
            continue
        with open(p, "r", encoding="utf-8") as f:
            text = f.read()
        orig = text
        for old, new in RENAMES.items():
            text = text.replace(f'"{old}"', f'"{new}"')
        if text != orig:
            with open(p, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"  {fn}: updated")


def validate():
    """Re-audit: no parent-leaf collisions should remain."""
    with open(XCSTRINGS, "r", encoding="utf-8") as f:
        d = json.load(f)
    keys = set(d["strings"].keys())
    collisions = []
    for k in keys:
        parts = k.split(".")
        for i in range(1, len(parts)):
            prefix = ".".join(parts[:i])
            if prefix in keys:
                collisions.append((prefix, k))
    if collisions:
        print(f"FAIL: {len(collisions)} collisions still present")
        for p, c in collisions[:10]:
            print(f"  {p!r} <-> {c!r}")
        sys.exit(1)
    print(f"OK: no parent-leaf collisions remaining ({len(keys)} keys total)")


def main():
    print("=" * 60)
    print("DEL-121 #5: Parent-Leaf-Collision Fix")
    print("=" * 60)
    print(f"Renames: {len(RENAMES)}")
    print()
    patch_xcstrings()
    patch_swift_sources()
    print()
    print("-> Updating downstream scripts...")
    patch_scripts()
    print()
    print("-> Re-auditing...")
    validate()


if __name__ == "__main__":
    main()
