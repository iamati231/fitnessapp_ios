"""Regenerate TRANSLATIONS.md from xcstrings + scan for hardcoded strings.

Run from project root: python .scripts/generate_translations_md.py
"""
import json
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..")
XCSTRINGS = os.path.join(ROOT, "Sources", "FitnessAppUI", "Resources", "Localizable.xcstrings")
UI_DIR = os.path.join(ROOT, "Sources", "FitnessAppUI")
OUT = os.path.join(ROOT, "TRANSLATIONS.md")


def md_escape(s):
    if s is None:
        return ""
    return s.replace("|", "\\|").replace("\n", "<br>")


def extract(entry, lang):
    loc = entry.get("localizations", {}).get(lang, {})
    if "stringUnit" in loc:
        return loc["stringUnit"].get("value", "")
    vars_ = loc.get("variations", {}).get("plural", {})
    if vars_:
        parts = []
        for kind in ("one", "other", "zero", "two", "few", "many"):
            if kind in vars_:
                val = vars_[kind].get("stringUnit", {}).get("value", "")
                parts.append(f"[{kind}] {val}")
        return " / ".join(parts)
    return ""


def main():
    with open(XCSTRINGS, "r", encoding="utf-8") as f:
        data = json.load(f)

    total = len(data["strings"])
    has_de = has_en = has_tr = 0
    rows = []
    plural_keys = []

    for key, entry in sorted(data["strings"].items()):
        de = extract(entry, "de")
        en = extract(entry, "en")
        tr = extract(entry, "tr")
        has_plural = "plural" in str(entry.get("localizations", {}).get("de", {}).get("variations", {}))
        if has_plural:
            plural_keys.append(key)
        if de:
            has_de += 1
        if en:
            has_en += 1
        if tr:
            has_tr += 1
        rows.append((key, de, en, tr, has_plural))

    def ns_key(k):
        if k.startswith("%") or k[0].isdigit():
            return "zzz_" + k
        return k

    rows.sort(key=lambda r: ns_key(r[0]))

    # Scan for hardcoded strings
    SKIP_FILES = {
        "PreviewSupport.swift",
        "BundleHelpers.swift",
        "Theme.swift",
        "DeltiqFormSection.swift",
        "Compatibility.swift",
    }
    PATTERNS = [
        re.compile(r'Text\("([A-ZÄÖÜa-zäöüß][^"]*)"\s*[\),]'),
        re.compile(r'Button\("([A-ZÄÖÜa-zäöüß][^"]*)"\s*[\),]'),
        re.compile(r'Label\("([A-ZÄÖÜa-zäöüß][^"]*)"\s*,'),
        re.compile(r'navigationTitle\("([A-ZÄÖÜa-zäöüß][^"]*)"\s*\)'),
        re.compile(r'\.accessibilityLabel\("([A-ZÄÖÜa-zäöüß][^"]*)"\s*\)'),
        re.compile(r'ContentUnavailableView\(\s*"([A-ZÄÖÜa-zäöüß][^"]*)"'),
        re.compile(r'Picker\("([A-ZÄÖÜa-zäöüß][^"]*)"\s*,'),
        re.compile(r'\.confirmationDialog\(\s*"([A-ZÄÖÜa-zäöüß][^"]*)"'),
        re.compile(r'Toggle\("([A-ZÄÖÜa-zäöüß][^"]*)"\s*,'),
        re.compile(r'TextField\("([A-ZÄÖÜa-zäöüß][^"]*)"\s*[,)]'),
        re.compile(r'LabeledContent\("([A-ZÄÖÜa-zäöüß][^"]*)"\s*,'),
    ]

    def looks_german(s):
        if len(s) < 2:
            return False
        if any(c in s for c in "äöüÄÖÜß"):
            return True
        common_de = {
            "der", "die", "das", "und", "ist", "sei", "dein", "deine", "sich",
            "ein", "eine", "noch", "beim", "vom", "zum", "zur", "dem", "den",
            "wie", "was", "bis", "aus", "für", "an", "bei", "mit", "ohne",
            "über", "auf", "unter", "seit", "nach", "vor",
        }
        words = re.findall(r"\b[a-zäöüß]+\b", s.lower())
        if any(w in common_de for w in words):
            return True
        suffixes = ["ung", "heit", "keit", "chen", "lein", "schaft", "tum"]
        if any(s.endswith(suf) for suf in suffixes):
            return True
        vocab = {
            "Übung", "Übungen", "Plan", "Pläne", "Workout", "Workouts",
            "Training", "Trainings", "Satz", "Sätze", "Pause", "Pausen",
            "Tag", "Tage", "Woche", "Wochen", "Gewicht", "Distanz", "Verlauf",
            "Beenden", "Speichern", "Abbrechen", "Weiter", "Zurück", "Fertig",
            "Mehr", "Neue", "Neuer", "Neues", "Letzte", "Letzter", "Letztes",
            "Aktiv", "Aktive", "Aktiver", "Hinzufügen", "Bearbeiten",
            "Löschen", "Schließen", "Trainings-Tage", "Trainings-Plan",
        }
        return any(w in vocab for w in s.split())

    findings = {}
    for dirpath, _, files in os.walk(UI_DIR):
        for fn in files:
            if not fn.endswith(".swift"):
                continue
            if fn in SKIP_FILES:
                continue
            fp = os.path.join(dirpath, fn)
            try:
                with open(fp, "r", encoding="utf-8") as f:
                    lines = f.readlines()
            except Exception:
                continue
            for lineno, line in enumerate(lines, 1):
                if line.lstrip().startswith("//") or line.lstrip().startswith("///"):
                    continue
                if "bundle: .module" in line:
                    continue
                if "String(localized:" in line:
                    continue
                for pat in PATTERNS:
                    for match in pat.finditer(line):
                        s = match.group(1)
                        if not looks_german(s):
                            continue
                        if re.match(r"^[a-z][a-zA-Z]*(\.[a-zA-Z]+)+$", s):
                            continue
                        findings.setdefault(fn, []).append((lineno, s))

    for fn in findings:
        seen = set()
        out = []
        for lineno, s in findings[fn]:
            if (lineno, s) not in seen:
                seen.add((lineno, s))
                out.append((lineno, s))
        findings[fn] = out

    hc_total = sum(len(v) for v in findings.values())

    # ─── Write Markdown ──────────────────────────────────────────
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("# Deltiq — Translation Source-of-Truth\n\n")
        f.write(f"**Gesamt: {total} Keys im String Catalog + {hc_total} noch hartkodierte Strings im Code.**\n\n")
        f.write("## Coverage-Status (Catalog)\n\n")
        f.write("| Sprache | Übersetzt | Fehlt |\n")
        f.write("|---|---|---|\n")
        f.write(f"| 🇩🇪 Deutsch (DE) | **{has_de} / {total}** ({100*has_de//total}%) | {total-has_de} |\n")
        f.write(f"| 🇬🇧 English (EN) | **{has_en} / {total}** ({100*has_en//total}%) | {total-has_en} |\n")
        f.write(f"| 🇹🇷 Türkçe (TR) | **{has_tr} / {total}** ({100*has_tr//total}%) | {total-has_tr} |\n\n")
        f.write("Wenn du EN/TR aktualisierst:\n")
        f.write("- Per Xcode: öffne `Sources/FitnessAppUI/Resources/Localizable.xcstrings`, Apple's String-Catalog-Editor markiert „needs translation\" automatisch.\n")
        f.write("- Per CSV-Export aus dieser Tabelle → ChatGPT / DeepL → zurück in die xcstrings importieren.\n")
        f.write("- Per direktem JSON-Edit (vorsichtig, JSON-Syntax muss valide bleiben).\n\n")
        f.write("Quelle: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`\n\n")
        f.write("Tabellenformat: leere EN/TR-Spalten brauchen Übersetzung. Plural-Keys sind separat aufgelistet — die haben one/other-Varianten.\n\n")

        # Group by namespace
        namespaces = {}
        for r in rows:
            if r[4]:
                continue
            ns = r[0].split(".")[0] if "." in r[0] else "misc"
            namespaces.setdefault(ns, []).append(r)

        for ns in sorted(namespaces.keys()):
            f.write(f"\n## `{ns}.*`  ({len(namespaces[ns])} Keys)\n\n")
            f.write("| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |\n")
            f.write("|---|---|---|---|\n")
            for key, de, en, tr, _ in namespaces[ns]:
                f.write(f"| `{key}` | {md_escape(de)} | {md_escape(en)} | {md_escape(tr)} |\n")

        if plural_keys:
            f.write("\n\n---\n\n## 🔢 Plural-Keys (one/other-Varianten)\n\n")
            f.write("Diese Keys haben Plural-Varianten — beide Formen sind übersetzt.\n\n")
            for r in rows:
                if not r[4]:
                    continue
                key, de, en, tr, _ = r
                f.write(f"\n### `{key}`\n\n")
                f.write("| Sprache | one | other |\n")
                f.write("|---|---|---|\n")
                for lang_code, lang_label in [("de", "Deutsch"), ("en", "English"), ("tr", "Türkçe")]:
                    vars_ = data["strings"][key].get("localizations", {}).get(lang_code, {}).get("variations", {}).get("plural", {})
                    one = vars_.get("one", {}).get("stringUnit", {}).get("value", "")
                    other = vars_.get("other", {}).get("stringUnit", {}).get("value", "")
                    f.write(f"| {lang_label} | {md_escape(one)} | {md_escape(other)} |\n")

        # Hardcoded section
        f.write("\n\n---\n\n# 🚧 Hartkodierte deutsche Strings (noch nicht im Catalog)\n\n")
        f.write(f"Stand: {hc_total} hartkodierte deutsche Strings über {len(findings)} Dateien gefunden ")
        f.write("(per Heuristik — false positives möglich, beim Refactor wird jede Stelle nochmal geprüft).\n\n")
        f.write("Diese Strings müssen in einem späteren i18n-Sweep (DEL-073 Phase 2-4) nach `Localizable.xcstrings` migriert werden:\n\n")
        f.write("1. Active Workout (ActiveWorkoutView, ExerciseCard, SetRow, WorkoutSummaryView)\n")
        f.write("2. Plan-Editor (PlanEditorView, DayEditorView, ProgramTemplatePickerView)\n")
        f.write("3. Library (ExerciseLibraryData, Domain-Enum-Labels)\n\n")

        sorted_files = sorted(findings.items(), key=lambda kv: -len(kv[1]))
        for fn, items in sorted_files:
            f.write(f"\n## `{fn}`  ({len(items)} Strings)\n\n")
            f.write("| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |\n")
            f.write("|---|---|---|---|\n")
            for lineno, s in items:
                safe = s.replace("|", "\\|").replace("\n", "<br>")
                f.write(f"| {lineno} | {safe} |  |  |\n")

    print(f"Generated: {OUT}")
    print(f"Catalog: {total} keys (DE: {has_de}, EN: {has_en}, TR: {has_tr})")
    print(f"Hardcoded: {hc_total} strings in {len(findings)} files")


if __name__ == "__main__":
    main()
