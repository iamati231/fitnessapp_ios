#!/usr/bin/env python3
"""DEL-145: entfernt 'profile.coaching.runCoach' - verwaist, nachdem der
Laufcoach-Schalter mit cardioCoachingEnabled vereinheitlicht wurde (keine
konkurrierenden Schalter mehr, siehe ProfileEditorView.cardioCard)."""
import json
from pathlib import Path

REPO = Path("/home/user/fitnessapp_ios")
CATALOG = REPO / "Sources" / "FitnessAppUI" / "Resources" / "Localizable.xcstrings"
DEAD_KEYS = ["profile.coaching.runCoach"]

def main() -> int:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data["strings"]
    deleted = sum(1 for k in DEAD_KEYS if strings.pop(k, None) is not None)
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"DEL-145 sweep: deleted={deleted}, remaining={len(strings)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
