"""Step 5: check every opening line in output/_work/lines.json against the profile's rules."""
import json
import re
import sys

import pandas as pd

from common import OUT, WORK, profile

CONTRACTION = re.compile(r"\b\w+(n't|'re|'ve|'ll|'m|'d)\b|\b(it's|that's|there's|what's|let's)\b", re.I)


def main() -> None:
    p = profile()
    rules = p["opening_lines"]
    f = WORK / "lines.json"
    if not f.exists():
        raise SystemExit("No output/_work/lines.json yet.")
    lines = json.loads(f.read_text(encoding="utf-8"))
    need = pd.read_csv(OUT / "worklist.csv", dtype=str, keep_default_na=False)["contact_id"]
    banned = [b for b in rules.get("banned_phrases", []) if b]
    problems = [f"{cid}: no opening line" for cid in need if cid not in lines]
    for cid, ln in lines.items():
        for lang in rules.get("languages", ["en"]) + ["en"]:
            text = ln.get(lang, "")
            if not text:
                continue
            words = len(text.split())
            if words > rules.get("max_words", 60):
                problems.append(f"{cid} {lang}: {words} words")
            for b in banned:
                if b.lower() in text.lower():
                    problems.append(f"{cid} {lang}: banned phrase {b!r}")
            if rules.get("no_contractions") and lang == "en" and CONTRACTION.search(text):
                problems.append(f"{cid} {lang}: contraction {CONTRACTION.search(text).group(0)!r}")
    if problems:
        sys.exit("\n".join(problems))
    print(f"All {len(lines)} lines pass.")


if __name__ == "__main__":
    main()
