#!/usr/bin/env python3
"""
Robuster Dead-Catalog-Audit (v3).

Approach: simple-substring statt regex. Fuer jeden Catalog-Key K:
  * Wenn `"K"` (mit Quotes) IRGENDWO im Swift-Code vorkommt → referenced
  * Wenn K als Praefix von einer dynamischen Konstruktion gematcht wird
    (siehe Prefix-Patterns unten) → auch referenced
  * Sonst → confirmed unused

Catches Ternary-Expressions, Dictionary-Werte, Array-Eintraege, etc. —
alles wo die String-Literale auftreten, egal wie sie weiterverarbeitet
werden.
"""
from __future__ import annotations
import json
import re
import glob
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"

data = json.loads(CATALOG.read_text(encoding="utf-8"))
catalog_keys = set(data["strings"].keys())

# Concatenate ALL Swift source code into one big text blob
swift_text = ""
for ext_dir in ["Sources", "App"]:
    for p in glob.glob(f"{ext_dir}/**/*.swift", recursive=True):
        swift_text += Path(p).read_text(encoding="utf-8") + "\n"

# Phase A: direkt-vorkommende Keys via `"key"`-Substring
referenced: set[str] = set()
for k in catalog_keys:
    if f'"{k}"' in swift_text:
        referenced.add(k)

# Phase B: dynamische Patterns — sammle alle Praefix-Konstruktoren
dynamic_prefixes: list[tuple[str, str | None]] = []  # (prefix, optional_suffix)

# B1: `"prefix.\(rawValue).suffix"`-Pattern
for m in re.finditer(r'"([a-z][a-zA-Z0-9_.]+)\\\(rawValue\)\.([a-zA-Z0-9_]+)"', swift_text):
    dynamic_prefixes.append((m.group(1), m.group(2)))

# B2: `"prefix.\(rawValue)"`-Pattern (suffix-less)
for m in re.finditer(r'"([a-z][a-zA-Z0-9_.]+)\\\(rawValue\)"', swift_text):
    dynamic_prefixes.append((m.group(1), None))

# B3: `"prefix.\(someVar)"` — generic interpolation, prefix-only match
for m in re.finditer(r'"([a-z][a-zA-Z0-9_.]+)\\\([a-zA-Z_][a-zA-Z0-9_.]*\)"', swift_text):
    dynamic_prefixes.append((m.group(1), None))

# B4: 3-level matrix `"prefix.\(a).\(b).\(c)"`
for m in re.finditer(
    r'"([a-z][a-zA-Z0-9_.]+)\\\([a-zA-Z_][a-zA-Z0-9_.]*\)\.\\\([a-zA-Z_][a-zA-Z0-9_.]*\)\.\\\([a-zA-Z_][a-zA-Z0-9_.]*\)"',
    swift_text,
):
    dynamic_prefixes.append((m.group(1), None))

# B5: 2-level matrix `"prefix.\(a).\(b)"`
for m in re.finditer(
    r'"([a-z][a-zA-Z0-9_.]+)\\\([a-zA-Z_][a-zA-Z0-9_.]*\)\.\\\([a-zA-Z_][a-zA-Z0-9_.]*\)"',
    swift_text,
):
    dynamic_prefixes.append((m.group(1), None))

# B6: pluralized(baseKey, ...) → baseKey.one + baseKey.other
plural_bases: set[str] = set()
for m in re.finditer(r'pluralized\(\s*"([a-z][a-zA-Z0-9_.]+)"', swift_text):
    plural_bases.add(m.group(1))

# Apply dynamic-prefix logic
for k in catalog_keys:
    if k in referenced:
        continue
    for prefix, suffix in dynamic_prefixes:
        if not k.startswith(prefix):
            continue
        # If suffix is constrained, key must end in `.suffix`
        if suffix and not k.endswith("." + suffix):
            continue
        # Match — mark as referenced
        referenced.add(k)
        break
    if k in referenced:
        continue
    # Plural-base check
    for base in plural_bases:
        if k == f"{base}.one" or k == f"{base}.other":
            referenced.add(k)
            break

# Special-case: localizationKey assignments in ExerciseLibraryData /
# ProgramTemplates / DaySpec — the build-time-set string is a key
# (already covered by Phase A since these are literal strings).

unused = sorted(catalog_keys - referenced)
print(f"Total catalog keys: {len(catalog_keys)}")
print(f"Referenced:         {len(referenced)}")
print(f"UNUSED:             {len(unused)}")
print()
print("=== UNUSED KEYS (safe to delete) ===")
for k in unused:
    print(f"  {k}")
