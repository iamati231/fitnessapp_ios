"""
Liest exercise_gif_overrides.json + exercises_cache.json,
extrahiert EN + TR Ausfuehrungsschritte und uebersetzt EN -> DE via Claude API.
Schreibt Sources/DeltiqCore/Resources/exercise_instructions.json.

Aufruf:
    ANTHROPIC_API_KEY=sk-ant-... python .scripts/build_exercise_instructions.py
"""
import json, os, re, sys, time, unicodedata
from pathlib import Path

try:
    import anthropic
except ImportError:
    sys.exit("anthropic-Paket nicht installiert: pip install anthropic")

ROOT = Path(__file__).parent.parent
OVERRIDES_JSON = ROOT / "exercise_gif_overrides.json"
CACHE_JSON = ROOT / "exercise_gif_overrides_cache.json"
OUT_JSON = ROOT / "Sources" / "DeltiqCore" / "Resources" / "exercise_instructions.json"

CACHE_DIR = Path(os.environ.get(
    "CLAUDE_SCRATCHPAD",
    Path.home() / ".cache" / "deltiq-scripts"
))
CACHE_DIR.mkdir(parents=True, exist_ok=True)
TRANS_CACHE = CACHE_DIR / "exercise_instructions_de_cache.json"


def normalize(name: str) -> str:
    working = name.replace("ß", "ss")
    working = "".join(
        c for c in unicodedata.normalize("NFD", working)
        if unicodedata.category(c) != "Mn"
    )
    working = working.lower()
    filtered = "".join(
        c if c.isascii() and (c.isalpha() or c.isdigit()) else " "
        for c in working
    )
    return " ".join(filtered.split())


def load_exercises_cache() -> dict:
    """Exercises-Cache laden (Pfad aus Umgebungsvariable oder Standard-Scratchpad)."""
    path = os.environ.get("EXERCISES_CACHE_JSON")
    if path and Path(path).exists():
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return {ex["id"]: ex for ex in data}
    sys.exit(
        "EXERCISES_CACHE_JSON nicht gesetzt oder Datei fehlt.\n"
        "Beispiel: EXERCISES_CACHE_JSON=/pfad/zur/exercises_cache.json python .scripts/build_exercise_instructions.py"
    )


def translate_batch(client: "anthropic.Anthropic", batch: list[tuple[str, list[str]]]) -> dict[str, list[str]]:
    """Uebersetzt eine Liste von (key, en_steps) EN -> DE. Gibt {key: de_steps} zurueck."""
    items_text = "\n\n".join(
        f"KEY: {key}\n" + "\n".join(f"{i+1}. {s}" for i, s in enumerate(steps))
        for key, steps in batch
    )
    prompt = (
        "Uebersetze die folgenden Fitnessübungs-Ausfuehrungsschritte von Englisch auf Deutsch. "
        "Fachbegriffe der Fitnessbranche auf Deutsch verwenden. "
        "Jede Schritt-Nummer beibehalten. Nur die Uebersetzung ausgeben, "
        "exakt dasselbe Format: KEY: <key> gefolgt von nummerierten Schritten.\n\n"
        + items_text
    )
    msg = client.messages.create(
        model="claude-haiku-5-5",
        max_tokens=4096,
        messages=[{"role": "user", "content": prompt}],
    )
    result = {}
    current_key = None
    current_steps: list[str] = []
    for line in msg.content[0].text.splitlines():
        line = line.strip()
        if line.startswith("KEY: "):
            if current_key and current_steps:
                result[current_key] = current_steps
            current_key = line[5:].strip()
            current_steps = []
        elif re.match(r"^\d+\.\s", line) and current_key:
            current_steps.append(re.sub(r"^\d+\.\s*", "", line))
    if current_key and current_steps:
        result[current_key] = current_steps
    return result


def main() -> None:
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        sys.exit("ANTHROPIC_API_KEY nicht gesetzt.")

    client = anthropic.Anthropic(api_key=api_key)

    overrides: dict[str, str] = json.loads(OVERRIDES_JSON.read_text(encoding="utf-8"))
    cache_data = load_exercises_cache()

    # Bestehende DE-Uebersetzungen laden (Resume-Unterstuetzung)
    de_cache: dict[str, list[str]] = {}
    if TRANS_CACHE.exists():
        de_cache = json.loads(TRANS_CACHE.read_text(encoding="utf-8"))
        print(f"Bestehende Uebersetzungen aus Cache geladen: {len(de_cache)}")

    # Alle 193 Uebungen aufloesen
    entries: list[tuple[str, str, list[str], list[str]]] = []
    for override_key, gif in overrides.items():
        m = re.match(r"^(\d+)-", gif)
        if not m:
            continue
        gif_id = m.group(1).zfill(4)
        ex = cache_data.get(gif_id)
        if not ex:
            continue
        en_steps = ex.get("instruction_steps", {}).get("en", [])
        tr_steps = ex.get("instruction_steps", {}).get("tr", [])
        if not en_steps:
            continue
        norm_key = normalize(override_key)
        entries.append((norm_key, gif_id, en_steps, tr_steps))

    print(f"Zu verarbeiten: {len(entries)} Uebungen")

    # Uebersetzung in Batches (10 Uebungen pro API-Aufruf)
    to_translate = [(k, en) for k, _, en, _ in entries if k not in de_cache]
    print(f"Noch zu uebersetzen: {len(to_translate)}")

    BATCH_SIZE = 10
    for i in range(0, len(to_translate), BATCH_SIZE):
        batch = to_translate[i:i + BATCH_SIZE]
        print(f"Batch {i // BATCH_SIZE + 1}: {[k for k, _ in batch]}")
        try:
            translated = translate_batch(client, batch)
            de_cache.update(translated)
            # Zwischenstand speichern
            TRANS_CACHE.write_text(json.dumps(de_cache, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"  OK: {len(translated)} uebersetzt, Cache gespeichert")
        except Exception as e:
            print(f"  FEHLER: {e}")
        time.sleep(0.5)

    # exercise_instructions.json aufbauen
    result: dict[str, dict[str, list[str]]] = {}
    missing_de = []
    for norm_key, gif_id, en_steps, tr_steps in entries:
        de_steps = de_cache.get(norm_key)
        if not de_steps:
            missing_de.append(norm_key)
            de_steps = en_steps  # Fallback auf EN
        result[norm_key] = {"de": de_steps, "en": en_steps, "tr": tr_steps}

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nGespeichert: {OUT_JSON}")
    print(f"  Eintraege: {len(result)}")
    if missing_de:
        print(f"  Ohne DE (EN-Fallback): {missing_de}")
    else:
        print("  Alle Uebungen auf Deutsch verfuegbar.")


if __name__ == "__main__":
    main()
