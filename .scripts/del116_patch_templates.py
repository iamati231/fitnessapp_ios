"""DEL-116 — annotate every ProgramTemplate(...) init with taglineKey,
focusKey, descriptionKey. Idempotent.

Inserts the keys directly after the corresponding existing literal
(e.g. after `tagline: "..."` → adds `,\\n            taglineKey: "..."`).
"""
import os
import re
import sys

ROOT          = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PROGRAMS_FILE = os.path.join(ROOT, "Sources", "FitnessAppCore", "Programs", "ProgramTemplates.swift")

# id -> suffix (matches del116_authoritative_translations.PROGRAMS)
SUFFIX = {
    "full_body":          "fullBody3x",
    "fat_loss_fullbody":  "fatBurnFullBody",
    "home_gym_hero":      "homeGymHero",
    "bodyweight_mastery": "bodyweightMastery",
    "push_pull_legs":     "pushPullLegs",
    "upper_lower":        "upperLower",
    "arnold_split":       "arnoldSplit",
    "bro_split":          "broSplit",
    "powerlifting_5x5":   "powerlifting5x5",
    "powerlifting_3x5":   "powerlifting3x5",
    "football_athletic":  "footballAthletic",
    "hybrid_beginner":    "hybridBeginner",
    "hybrid_balanced":    "hybridBalanced",
    "hybrid_performance": "hybridPerformance",
}


def main():
    with open(PROGRAMS_FILE, "r", encoding="utf-8") as f:
        text = f.read()
    original = text

    # Split text by `ProgramTemplate(` initializers
    chunks = re.split(r'(ProgramTemplate\()', text)
    out = []
    annotated = 0
    for i, chunk in enumerate(chunks):
        if i == 0 or chunks[i - 1] != "ProgramTemplate(":
            out.append(chunk)
            continue
        # `chunk` is the body of one ProgramTemplate init plus everything
        # after. We need to find the matching closing `)` for THIS init.
        depth = 1
        in_string = False
        j = 0
        while j < len(chunk) and depth > 0:
            c = chunk[j]
            if c == '"' and (j == 0 or chunk[j - 1] != "\\"):
                in_string = not in_string
            elif not in_string:
                if c == '(':
                    depth += 1
                elif c == ')':
                    depth -= 1
                    if depth == 0:
                        break
            j += 1
        body = chunk[:j]   # everything up to the matching `)`
        tail = chunk[j:]   # closing `)` and after

        # Find the id
        m_id = re.search(r'id:\s*"([^"]+)"', body)
        if not m_id:
            out.append(chunk)
            continue
        pid = m_id.group(1)
        if pid not in SUFFIX:
            out.append(chunk)
            continue
        suffix = SUFFIX[pid]

        # Skip if already annotated with all three keys
        if 'taglineKey:' in body and 'focusKey:' in body and 'descriptionKey:' in body:
            out.append(chunk)
            continue

        # Insert taglineKey after the tagline literal line
        body = re.sub(
            r'(tagline:\s*"[^"]+",)(?!\s*\n\s*taglineKey)',
            r'\1\n        taglineKey: "plan.template.' + suffix + r'.tagline",',
            body,
            count=1,
        )
        # Insert descriptionKey after the descriptionText literal line
        body = re.sub(
            r'(descriptionText:\s*"[^"]+",)(?!\s*\n\s*descriptionKey)',
            r'\1\n        descriptionKey: "plan.template.' + suffix + r'.description",',
            body,
            count=1,
        )
        # Insert focusKey after the focus literal line
        body = re.sub(
            r'(focus:\s*"[^"]+",)(?!\s*\n\s*focusKey)',
            r'\1\n        focusKey: "plan.template.' + suffix + r'.focus",',
            body,
            count=1,
        )
        annotated += 1
        out.append(body + tail)

    new_text = "".join(out)
    if new_text == original:
        print("ProgramTemplates: nothing to patch")
        return
    with open(PROGRAMS_FILE, "w", encoding="utf-8") as f:
        f.write(new_text)
    print(f"ProgramTemplates: annotated {annotated} templates with tagline/focus/description keys")


if __name__ == "__main__":
    main()
