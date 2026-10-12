"""Baut das App-Uebung -> GIF-Mapping aus zwei externen GitHub-Repos:

  - hasaneyldrm/exercises-dataset  (Metadaten, data/exercises.json, 17 MB,
    wird NIE committet — bleibt in .scripts/.cache/, gitignored)
  - arvids-unavailable/openGym     (die eigentlichen 180x180-GIFs unter
    media/gif/, Datei-Listing per blobless Git-Clone — kein Download der
    ~1300 Binaries)

Erzeugt:
  - exercise_gif_map.json        Dataset-Katalog, nur Eintraege mit
                                  tatsaechlich existierendem GIF.
  - exercise_gif_overrides.json  Von Hand gepflegte Freigaben
                                  (App-Uebungsname -> gifFile). Wird NICHT
                                  ueberschrieben, falls schon vorhanden.
  - GIF_MATCH_REPORT.md          Sicher / unsicher (Top-3) / ohne GIF.
  - Sources/FitnessAppCore/Exercises/ExerciseGifResolution.swift
                                  Generierte Swift-Konstanten (Automatik-Treffer).
  - Sources/FitnessAppCore/Exercises/ExerciseGifOverrides.swift
                                  Generierte Swift-Konstanten (aus den Overrides).
  - Sources/FitnessAppUI/Resources/ExerciseGifs/*.gif
                                  Nur die tatsaechlich gematchten GIF-Dateien.

Lauf von Repo-Root (stdlib-only, kein pip-Install noetig):
    python3 .scripts/build_exercise_gif_map.py [--refresh]

--refresh erzwingt Neu-Download von exercises.json und ein frisches
openGym-Tree-Listing statt den lokalen Cache (.scripts/.cache/) zu nutzen.

Unsichere Faelle bekommen bewusst KEIN GIF, bis sie in
exercise_gif_overrides.json von Hand freigegeben wurden (siehe
GIF_MATCH_REPORT.md) — nie ein falsches GIF raten.
"""

import collections
import difflib
import json
import os
import re
import shutil
import subprocess
import sys
import unicodedata
import urllib.error
import urllib.request

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
CACHE_DIR = os.path.join(os.path.dirname(__file__), ".cache")

DATASET_REPO = "https://github.com/hasaneyldrm/exercises-dataset.git"
DATASET_JSON_URL_TEMPLATE = "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/{sha}/data/exercises.json"
GIF_REPO = "https://github.com/arvids-unavailable/openGym.git"
GIF_RAW_BASE_TEMPLATE = "https://raw.githubusercontent.com/arvids-unavailable/openGym/{sha}/media/gif/"

LIBRARY_SWIFT = os.path.join(ROOT, "Sources/FitnessAppCore/Programs/ExerciseLibraryData.swift")
XCSTRINGS = os.path.join(ROOT, "Sources/FitnessAppUI/Resources/Localizable.xcstrings")

OVERRIDES_JSON = os.path.join(ROOT, "exercise_gif_overrides.json")
MAP_JSON = os.path.join(ROOT, "exercise_gif_map.json")
REPORT_MD = os.path.join(ROOT, "GIF_MATCH_REPORT.md")

GEN_RESOLUTION_SWIFT = os.path.join(ROOT, "Sources/FitnessAppCore/Exercises/ExerciseGifResolution.swift")
GEN_OVERRIDES_SWIFT = os.path.join(ROOT, "Sources/FitnessAppCore/Exercises/ExerciseGifOverrides.swift")
GIFS_DEST_DIR = os.path.join(ROOT, "Sources/FitnessAppUI/Resources/ExerciseGifs")

SICHER_RATIO = 0.90
UNSICHER_RATIO_FLOOR = 0.70
AMBIGUOUS_MARGIN = 0.02
WORD_OVERLAP_MIN = 0.999

# Dataset-Equipment-Freitext -> App-`Equipment`-RawValue. Bewusst nicht
# gemappt (kein App-Aequivalent oder zu mehrdeutig): weighted, stability
# ball, assisted, medicine ball, rope, roller, bosu ball, wheel roller,
# upper body ergometer, skierg machine, hammer, stationary bike, tire,
# elliptical machine, stepmill machine. Volle beobachtete Vokabular-Liste
# landet im Report-Anhang, damit neue/unbekannte Werte sichtbar bleiben.
EQUIPMENT_SYNONYMS = {
    "body weight": "bodyweight",
    "dumbbell": "dumbbell",
    "cable": "cable",
    "barbell": "barbell",
    "ez barbell": "barbell",
    "olympic barbell": "barbell",
    "trap bar": "barbell",
    "leverage machine": "machine",
    "smith machine": "machine",
    "sled machine": "machine",
    "band": "band",
    "resistance band": "band",
    "kettlebell": "kettlebell",
}

# Woerter, die im Dataset-NAMEN das Equipment ausbuchstabieren (z.B. "Barbell
# Bench Press", "Lever Chest Press" — das Equipment-FELD sagt "leverage
# machine", der Name verwendet aber "lever"). Werden vor dem Fuzzy-Vergleich
# aus dem Namen entfernt, damit "Bankdrücken" (App, EN "Bench Press") nicht
# an einem laengeren/kuerzeren Equipment-Praefix vorbeigewertet wird (reines
# SequenceMatcher-Ratio bevorzugt sonst zufaellig kuerzere falsche Praefixe
# wie "Band" gegenueber "Barbell").
EQUIPMENT_NAME_TOKENS = {
    "body weight": set(),
    "dumbbell": {"dumbbell", "dumbbells"},
    "cable": {"cable"},
    "barbell": {"barbell"},
    "ez barbell": {"ez", "bar", "barbell"},
    "olympic barbell": {"olympic", "barbell"},
    "trap bar": {"trap", "bar"},
    "leverage machine": {"lever", "leverage", "machine"},
    "smith machine": {"smith", "machine"},
    "sled machine": {"sled", "machine"},
    "band": {"band"},
    "resistance band": {"resistance", "band"},
    "kettlebell": {"kettlebell", "kettlebells"},
    "weighted": {"weighted"},
    "assisted": {"assisted"},
    "medicine ball": {"medicine", "ball"},
    "stability ball": {"stability", "exercise", "ball"},
    "bosu ball": {"bosu", "ball"},
    "rope": {"rope"},
    "roller": {"roller"},
    "wheel roller": {"wheel", "roller"},
}

# Dataset `target` -> App-`MuscleGroup`-RawValue. Nur ein Tie-Breaker bei
# mehrdeutigen Fuzzy-Treffern, nie ein hartes Kriterium.
TARGET_TO_MUSCLE = {
    "abs": "core",
    "pectorals": "chest",
    "biceps": "biceps",
    "glutes": "glutes",
    "delts": "shoulders",
    "triceps": "triceps",
    "upper back": "back",
    "lats": "back",
    "calves": "calves",
    "quads": "quads",
    "hamstrings": "hamstrings",
}

# Fallback, wenn `target` nicht gemappt werden konnte.
BODY_PART_TO_MUSCLE = {
    "back": "back",
    "waist": "core",
    "chest": "chest",
    "shoulders": "shoulders",
    "lower legs": "calves",
}


def log(*args):
    print(*args, file=sys.stderr)


# ── Normalisierung ───────────────────────────────────────────────────────
# 1:1-Port in Swift: ExerciseMediaProvider.normalizedKey(for:). Muss fuer
# dieselbe Eingabe IMMER denselben Key liefern wie die Swift-Seite, sonst
# laeuft die Laufzeit-Lookup ins Leere.

def normalize(s: str) -> str:
    s = s.replace("ß", "ss")
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower()
    # Klammern NUR als Satzzeichen entfernen, den Inhalt behalten — z.B.
    # "Shrug (KH)" vs. "Shrug (LH)" sind zwei verschiedene App-Uebungen und
    # muessen unterscheidbar bleiben (siehe build_normalized_pairs-Check).
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def normalize_token_sorted(s: str) -> str:
    return " ".join(sorted(normalize(s).split()))


def best_ratio(a: str, b: str) -> float:
    return max(
        difflib.SequenceMatcher(None, normalize(a), normalize(b)).ratio(),
        difflib.SequenceMatcher(None, normalize_token_sorted(a), normalize_token_sorted(b)).ratio(),
    )


def strip_equipment_tokens(name: str, equipment: str) -> str:
    """Entfernt Equipment-Woerter aus einem Dataset-Namen (z.B. "Barbell
    Bench Press" -> "bench press"), damit der Fuzzy-Vergleich die reine
    Bewegung trifft statt am Equipment-Praefix zu haengen."""
    tokens = EQUIPMENT_NAME_TOKENS.get(equipment.lower())
    if tokens is None:
        tokens = set(normalize(equipment).split())
    kept = [t for t in normalize(name).split() if t not in tokens]
    return " ".join(kept) if kept else normalize(name)


def word_overlap(app_name: str, candidate_name: str) -> float:
    """Anteil der App-Namens-Woerter, die WOERTLICH auch im Kandidaten
    vorkommen (asymmetrisch, keine Jaccard-Symmetrie). Schuetzt vor zwei
    Kurz-String-Fallen des reinen Zeichen-Ratios:
      - 'back squat' vs. 'hack squat': ein Buchstabe Unterschied, Ratio
        0.90, aber 'back' kommt im Kandidaten gar nicht vor.
      - 'wide push up' vs. 'side push up': 2 von 3 Woertern gemeinsam
        (Jaccard 0.67 waere durchgerutscht), aber 'wide' fehlt im
        Kandidaten komplett — andere Uebung.
    Verlangt quasi vollstaendige Praesenz aller App-Woerter im Kandidaten;
    zusaetzliche Woerter im Kandidaten (z.B. Restequipment) stoeren nicht."""
    app_tokens = set(normalize(app_name).split())
    cand_tokens = set(normalize(candidate_name).split())
    if not app_tokens:
        return 0.0
    return len(app_tokens & cand_tokens) / len(app_tokens)


def name_similarity(app_en_name: str, entry):
    """(ratio, word_overlap) fuer die bessere von Roh-/equipment-
    gestripptem Dataset-Namen gegen den App-EN-Namen."""
    stripped = strip_equipment_tokens(entry["name"], entry["equipment"])
    best_text = max((entry["name"], stripped), key=lambda t: best_ratio(app_en_name, t))
    return best_ratio(app_en_name, best_text), word_overlap(app_en_name, best_text)


# ── ExerciseLibraryData.swift parsen ─────────────────────────────────────
# Regex + Klammer-/String-bewusste Tiefenzaehlung, wie
# .scripts/del113_localize_library.py es fuer dieselbe Datei vormacht.
# Noetig, weil Namen selbst Klammern enthalten koennen, z.B.
# 'Reißen (Snatch)' oder 'Schrägbankdrücken (aufwärts)'.

def extract_spec_blocks(source: str):
    blocks = []
    marker = "ExerciseTemplateSpec("
    pos = 0
    while True:
        start = source.find(marker, pos)
        if start == -1:
            break
        i = start + len(marker)
        depth = 1
        in_string = False
        escape = False
        while i < len(source) and depth > 0:
            ch = source[i]
            if in_string:
                if escape:
                    escape = False
                elif ch == "\\":
                    escape = True
                elif ch == '"':
                    in_string = False
            else:
                if ch == '"':
                    in_string = True
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
            i += 1
        blocks.append(source[start + len(marker):i - 1])
        pos = i
    return blocks


def parse_library_specs(path: str):
    source = open(path, encoding="utf-8").read()
    specs = []
    for block in extract_spec_blocks(source):
        name_m = re.search(r'name:\s*"((?:[^"\\]|\\.)*)"', block)
        equip_m = re.search(r"equipment:\s*\.(\w+)", block)
        muscle_m = re.search(r"primaryMuscle:\s*\.(\w+)", block)
        key_m = re.search(r'localizationKey:\s*"([^"]+)"', block)
        if not name_m or not equip_m or not muscle_m:
            raise ValueError(f"Konnte Pflichtfelder nicht parsen: {block[:80]!r}")
        specs.append({
            "name": name_m.group(1),
            "equipment": equip_m.group(1),
            "primaryMuscle": muscle_m.group(1),
            "localizationKey": key_m.group(1) if key_m else None,
        })
    return specs


def load_en_names(path: str):
    data = json.load(open(path, encoding="utf-8"))
    out = {}
    for key, entry in data["strings"].items():
        if not key.startswith("exercise.name."):
            continue
        value = entry.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value")
        if value:
            out[key] = value
    return out


# ── Externe Daten laden (gecacht unter .scripts/.cache/) ────────────────

def fetch_url(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "fitnessapp-gif-mapper"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def git_remote_head_sha(repo_url: str, branch: str = "main") -> str:
    out = subprocess.run(
        ["git", "ls-remote", repo_url, branch],
        capture_output=True, text=True, check=True,
    )
    return out.stdout.split()[0]


def load_dataset(refresh: bool):
    os.makedirs(CACHE_DIR, exist_ok=True)
    sha_path = os.path.join(CACHE_DIR, "exercises-dataset.sha")
    json_path = os.path.join(CACHE_DIR, "exercises.json")
    if refresh or not os.path.exists(json_path) or not os.path.exists(sha_path):
        sha = git_remote_head_sha(DATASET_REPO)
        log(f"Lade exercises.json @ {sha[:12]} (~17 MB)...")
        raw = fetch_url(DATASET_JSON_URL_TEMPLATE.format(sha=sha))
        with open(json_path, "wb") as f:
            f.write(raw)
        with open(sha_path, "w") as f:
            f.write(sha)
    sha = open(sha_path).read().strip()
    data = json.load(open(json_path, encoding="utf-8"))
    return data, sha


def list_opengym_gifs(refresh: bool):
    """Listet media/gif/*.gif per blobless Git-Clone — laedt keine der
    ~1300 GIF-Binaries herunter, nur Commit-/Tree-Metadaten."""
    clone_dir = os.path.join(CACHE_DIR, "opengym-tree")
    if refresh and os.path.isdir(clone_dir):
        shutil.rmtree(clone_dir)
    if not os.path.isdir(clone_dir):
        log("Klone openGym (blobless, nur fuer Datei-Listing)...")
        subprocess.run(
            ["git", "clone", "--filter=blob:none", "--no-checkout", "--depth", "1", GIF_REPO, clone_dir],
            check=True, capture_output=True,
        )
    out = subprocess.run(
        ["git", "-C", clone_dir, "ls-tree", "-r", "HEAD", "--name-only", "--", "media/gif"],
        capture_output=True, text=True, check=True,
    )
    files = {line.rsplit("/", 1)[-1] for line in out.stdout.splitlines() if line.strip()}
    sha = subprocess.run(
        ["git", "-C", clone_dir, "rev-parse", "HEAD"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return files, sha


def gif_filename(entry) -> str:
    return entry["gif_url"].rsplit("/", 1)[-1]


# ── Matching ──────────────────────────────────────────────────────────────

def equipment_compatible(app_equipment: str, dataset_equipment: str) -> bool:
    """Bewusst STRENG: ein Dataset-Equipment ohne Eintrag in
    EQUIPMENT_SYNONYMS gilt als NICHT kompatibel, nicht als neutral. Sonst
    wuerden Modifier-Varianten wie "assisted sit-up" oder "weighted dip"
    unbemerkt als sicherer Treffer fuer eine normale Bodyweight-Uebung
    durchrutschen, obwohl sie visuell etwas anderes zeigen — im Zweifel
    soll so ein Fall in die 'unsicher'-Liste zur manuellen Freigabe fallen."""
    mapped = EQUIPMENT_SYNONYMS.get(dataset_equipment.lower())
    return mapped == app_equipment


def muscle_hint(entry):
    hint = TARGET_TO_MUSCLE.get(entry.get("target", "").lower())
    if hint:
        return hint
    return BODY_PART_TO_MUSCLE.get(entry.get("body_part", "").lower())


def match_library(specs, en_names, dataset, overrides):
    by_norm_exact = {}
    for e in dataset:
        by_norm_exact.setdefault(normalize(e["name"]), []).append(e)

    sicher, unsicher, ohne = [], [], []

    for spec in specs:
        name = spec["name"]

        # 1) Override (von Hand freigegeben)
        if name in overrides:
            sicher.append({"spec": spec, "gifFile": overrides[name], "reason": "override"})
            continue

        en_name = en_names.get(spec["localizationKey"]) if spec["localizationKey"] else None
        if not en_name:
            ohne.append({"spec": spec, "reason": "keine EN-Uebersetzung (localizationKey fehlt/unbekannt)"})
            continue

        # 2) Exakter normalisierter Namens-Match
        exact_candidates = by_norm_exact.get(normalize(en_name), [])
        if len(exact_candidates) == 1:
            e = exact_candidates[0]
            sicher.append({"spec": spec, "gifFile": gif_filename(e), "reason": "exact", "dataset": e})
            continue
        if len(exact_candidates) > 1:
            # 3) Mehrere namensgleiche Dataset-Eintraege -> Equipment entscheidet
            equip_matches = [e for e in exact_candidates if equipment_compatible(spec["equipment"], e["equipment"])]
            if len(equip_matches) == 1:
                e = equip_matches[0]
                sicher.append({"spec": spec, "gifFile": gif_filename(e), "reason": "exact+equipment", "dataset": e})
                continue
            unsicher.append({"spec": spec, "candidates": [(1.0, e) for e in exact_candidates[:3]]})
            continue

        # 4) Fuzzy mit hoher Schwelle. Equipment-Woerter werden vor dem
        # Vergleich aus dem Dataset-Namen gestrippt (siehe
        # best_ratio_with_equipment), sonst gewinnt ein kuerzeres falsches
        # Equipment-Praefix (z.B. "Band") rein rechnerisch gegen ein
        # laengeres richtiges ("Barbell"). Ranking nutzt zusaetzlich einen
        # kleinen Equipment-Match-Bonus, damit unter nahezu gleichen
        # Namens-Ratios die equipment-passende Variante gewinnt statt
        # zufaellig die erstbeste.
        def score(e):
            ratio, overlap = name_similarity(en_name, e)
            equip_ok = equipment_compatible(spec["equipment"], e["equipment"])
            combined = ratio + (0.05 if equip_ok else 0.0)
            return combined, ratio, overlap, equip_ok

        scored = sorted(((score(e), e) for e in dataset), key=lambda t: -t[0][0])
        (top_combined, top_ratio, top_overlap, top_equip_ok), top_e = scored[0]
        second_combined = scored[1][0][0] if len(scored) > 1 else 0.0
        ambiguous = (top_combined - second_combined) < AMBIGUOUS_MARGIN
        top_safe = top_ratio >= SICHER_RATIO and top_overlap >= WORD_OVERLAP_MIN

        if ambiguous and top_safe:
            # Mehrdeutig unter den Top-Kandidaten -> Muskelgruppe als
            # letzter Tie-Breaker, bevor es als unsicher eingestuft wird.
            second_e = scored[1][1]
            top_muscle_ok = muscle_hint(top_e) == spec["primaryMuscle"]
            second_muscle_ok = muscle_hint(second_e) == spec["primaryMuscle"]
            if top_equip_ok and top_muscle_ok and not second_muscle_ok:
                reason = "exact (equipment-variant)+muscle-tiebreak" if top_ratio >= 0.999 else f"fuzzy {top_ratio:.2f}+muscle-tiebreak"
                sicher.append({"spec": spec, "gifFile": gif_filename(top_e), "reason": reason, "dataset": top_e})
                continue

        if not ambiguous and top_safe and top_equip_ok:
            reason = "exact (equipment-variant)" if top_ratio >= 0.999 else f"fuzzy {top_ratio:.2f}"
            sicher.append({"spec": spec, "gifFile": gif_filename(top_e), "reason": reason, "dataset": top_e})
        elif top_ratio >= UNSICHER_RATIO_FLOOR:
            unsicher.append({"spec": spec, "candidates": [(r, e) for (_, r, _, _), e in scored[:3]]})
        else:
            ohne.append({"spec": spec, "reason": f"kein Kandidat (bester Ratio {top_ratio:.2f})"})

    return sicher, unsicher, ohne


# ── Output: JSON / Markdown / Swift ──────────────────────────────────────

def write_map_json(dataset_with_gifs):
    rows = [
        {
            "datasetId": e["id"],
            "nameEN": e["name"],
            "equipment": e["equipment"],
            "target": e["target"],
            "gifFile": gif_filename(e),
        }
        for e in sorted(dataset_with_gifs, key=lambda e: e["id"])
    ]
    with open(MAP_JSON, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return rows


def load_or_seed_overrides():
    if os.path.exists(OVERRIDES_JSON):
        return json.load(open(OVERRIDES_JSON, encoding="utf-8"))
    with open(OVERRIDES_JSON, "w", encoding="utf-8") as f:
        json.dump({}, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return {}


def write_report(sicher, unsicher, ohne, dataset_sha, gif_sha, total_specs, dataset):
    equip_counts = collections.Counter(e["equipment"].lower() for e in dataset)

    lines = []
    lines.append("# GIF-Match-Report")
    lines.append("")
    lines.append(f"- Dataset-Commit (`hasaneyldrm/exercises-dataset`): `{dataset_sha}`")
    lines.append(f"- GIF-Commit (`arvids-unavailable/openGym`): `{gif_sha}`")
    lines.append(f"- App-Uebungen gesamt: {total_specs}")
    lines.append("")
    lines.append(f"**{len(sicher)} sicher · {len(unsicher)} unsicher · {len(ohne)} ohne GIF**")
    lines.append("")

    lines.append("## Sicher zugeordnet")
    lines.append("")
    lines.append("| App-Übung | GIF | Match-Typ |")
    lines.append("|---|---|---|")
    for m in sorted(sicher, key=lambda m: m["spec"]["name"]):
        lines.append(f"| {m['spec']['name']} | `{m['gifFile']}` | {m['reason']} |")
    lines.append("")

    lines.append("## Unsicher — Top-3-Kandidaten (benötigt Freigabe)")
    lines.append("")
    lines.append("| App-Übung | Equipment | Kandidat 1 | Kandidat 2 | Kandidat 3 |")
    lines.append("|---|---|---|---|---|")
    for m in sorted(unsicher, key=lambda m: m["spec"]["name"]):
        cands = m["candidates"]

        def cell(c):
            ratio, e = c
            return f"{e['name']} ({ratio:.2f}, `{e['equipment']}`, `{gif_filename(e)}`)"

        row = [cell(cands[i]) if i < len(cands) else "—" for i in range(3)]
        lines.append(f"| {m['spec']['name']} | {m['spec']['equipment']} | {row[0]} | {row[1]} | {row[2]} |")
    lines.append("")
    lines.append(
        "Freigabe: gewünschten `gifFile`-Wert in `exercise_gif_overrides.json` "
        "unter dem exakten App-Übungsnamen eintragen und das Skript erneut laufen lassen."
    )
    lines.append("")

    lines.append("## Ohne GIF")
    lines.append("")
    lines.append("| App-Übung | Grund |")
    lines.append("|---|---|")
    for m in sorted(ohne, key=lambda m: m["spec"]["name"]):
        lines.append(f"| {m['spec']['name']} | {m['reason']} |")
    lines.append("")

    lines.append("## Zusammenfassung")
    lines.append("")
    lines.append(f"- Sicher: {len(sicher)}")
    lines.append(f"- Unsicher: {len(unsicher)}")
    lines.append(f"- Ohne GIF: {len(ohne)}")
    lines.append(f"- Gesamt: {total_specs}")
    lines.append("")

    lines.append("## Anhang: beobachtete Dataset-Equipment-Werte")
    lines.append("")
    lines.append("| Equipment (Dataset) | Anzahl | App-Equipment |")
    lines.append("|---|---|---|")
    for equip, count in equip_counts.most_common():
        mapped = EQUIPMENT_SYNONYMS.get(equip, "—")
        lines.append(f"| {equip} | {count} | {mapped} |")
    lines.append("")

    with open(REPORT_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def swift_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def build_normalized_pairs(pairs, label):
    """Dedupliziert auf normalisierten Key, erkennt echte Kollisionen
    (gleicher Key, unterschiedlicher Wert) als harten Fehler."""
    resolved = {}
    for raw_name, gif in pairs:
        key = normalize(raw_name)
        if key in resolved and resolved[key] != gif:
            raise ValueError(
                f"Normalisierungs-Kollision in {label}: {raw_name!r} -> {key!r} "
                f"kollidiert ({resolved[key]!r} vs. {gif!r})"
            )
        resolved[key] = gif
    return sorted(resolved.items())


def write_swift_table(path, type_name, pairs, header_comment):
    entries = ",\n".join(f'            ("{swift_escape(k)}", "{swift_escape(v)}")' for k, v in pairs)
    content = f"""// Generiert von .scripts/build_exercise_gif_map.py — nicht von Hand editieren.
{header_comment}

public enum {type_name} {{
    public static let byNormalizedName: [String: String] = Dictionary(
        uniqueKeysWithValues: [
{entries}
        ]
    )
}}
"""
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def download_gifs(needed_files: set, gif_sha: str):
    os.makedirs(GIFS_DEST_DIR, exist_ok=True)
    base = GIF_RAW_BASE_TEMPLATE.format(sha=gif_sha)

    existing = set(os.listdir(GIFS_DEST_DIR))
    for stale in sorted(existing - needed_files):
        os.remove(os.path.join(GIFS_DEST_DIR, stale))

    downloaded, skipped, failed = 0, 0, []
    for fname in sorted(needed_files):
        dest = os.path.join(GIFS_DEST_DIR, fname)
        if os.path.exists(dest) and os.path.getsize(dest) > 0:
            skipped += 1
            continue
        try:
            data = fetch_url(base + fname)
        except (urllib.error.URLError, urllib.error.HTTPError) as exc:
            failed.append((fname, str(exc)))
            continue
        if not data.startswith(b"GIF8") or len(data) == 0:
            failed.append((fname, "ungueltige GIF-Signatur"))
            continue
        with open(dest, "wb") as f:
            f.write(data)
        downloaded += 1
    return downloaded, skipped, failed, len(existing - needed_files)


def main():
    refresh = "--refresh" in sys.argv

    specs = parse_library_specs(LIBRARY_SWIFT)
    en_names = load_en_names(XCSTRINGS)
    log(f"{len(specs)} App-Uebungen aus ExerciseLibraryData.swift geladen.")

    dataset, dataset_sha = load_dataset(refresh)
    gif_files, gif_sha = list_opengym_gifs(refresh)
    log(f"{len(dataset)} Dataset-Eintraege, {len(gif_files)} GIF-Dateien in openGym gefunden.")

    dataset_with_gifs = [e for e in dataset if gif_filename(e) in gif_files]
    missing = len(dataset) - len(dataset_with_gifs)
    if missing:
        log(f"WARNUNG: {missing} Dataset-Eintraege verweisen auf ein fehlendes GIF — ausgeschlossen.")

    overrides = load_or_seed_overrides()

    # Override-GIFs muessen auf tatsaechlich existierende Dateien zeigen.
    valid_gif_files = {gif_filename(e) for e in dataset_with_gifs}
    for app_name, gif in overrides.items():
        if gif not in valid_gif_files:
            raise ValueError(f"Override fuer {app_name!r} verweist auf nicht existierendes GIF {gif!r}")

    sicher, unsicher, ohne = match_library(specs, en_names, dataset_with_gifs, overrides)

    write_map_json(dataset_with_gifs)
    write_report(sicher, unsicher, ohne, dataset_sha, gif_sha, len(specs), dataset_with_gifs)

    resolution_pairs = build_normalized_pairs(
        [(m["spec"]["name"], m["gifFile"]) for m in sicher if m["reason"] != "override"],
        "ExerciseGifResolution.swift",
    )
    write_swift_table(
        GEN_RESOLUTION_SWIFT, "ExerciseGifResolution", resolution_pairs,
        "// Automatische Treffer (sicher), Key = ExerciseMediaProvider.normalizedKey(for: name).",
    )

    overrides_pairs = build_normalized_pairs(list(overrides.items()), "ExerciseGifOverrides.swift")
    write_swift_table(
        GEN_OVERRIDES_SWIFT, "ExerciseGifOverrides", overrides_pairs,
        "// Aus exercise_gif_overrides.json — dort pflegen, nicht hier.",
    )

    needed_files = {m["gifFile"] for m in sicher}
    downloaded, skipped, failed, removed = download_gifs(needed_files, gif_sha)

    log("")
    log(f"Sicher: {len(sicher)} | Unsicher: {len(unsicher)} | Ohne GIF: {len(ohne)} | Gesamt: {len(specs)}")
    log(f"GIFs: {downloaded} neu geladen, {skipped} schon vorhanden, {removed} veraltete entfernt.")
    if failed:
        log(f"FEHLGESCHLAGEN ({len(failed)}):")
        for fname, reason in failed:
            log(f"  {fname}: {reason}")
        sys.exit(1)


if __name__ == "__main__":
    main()
