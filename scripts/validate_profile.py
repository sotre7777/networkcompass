"""Check profile.json for mistakes before running the pipeline."""
import re
import sys

from common import profile

KINDS = {"decision", "door", "investor", "low"}
SOURCES = {"matches", "investors", "referral_companies", "warm", "in_talks_leaders", "in_talks_rest"}
COLORS = {"blue", "green", "orange", "red", "yellow", "purple", "indigo", "teal", "pink", "gray"}


def main() -> None:
    p, errors = profile(), []
    if p.get("lens") not in ("job", "opportunity"):
        errors.append('lens must be "job" or "opportunity"')
    for key in ("owner", "goal", "target", "categories", "lists", "stages", "outreach", "opening_lines"):
        if key not in p:
            errors.append(f"missing {key}")
    if errors:
        raise SystemExit("\n".join(errors))
    if not p["owner"].get("background"):
        errors.append("owner.background is empty: opening lines need it")
    t = p["target"]
    if not t["near_low"] <= t["size_min"] <= t["size_max"] <= t["near_high"]:
        errors.append("target sizes must run near_low <= size_min <= size_max <= near_high")
    ids = [c["id"] for c in p["categories"]]
    if len(set(ids)) != len(ids):
        errors.append("category ids must be unique")
    for c in p["categories"]:
        if c.get("kind") not in KINDS:
            errors.append(f"category {c.get('id')}: kind must be one of {sorted(KINDS)}")
        for m in c.get("match", []):
            try:
                re.compile(m)
            except re.error as e:
                errors.append(f"category {c.get('id')}: bad pattern {m!r}: {e}")
    for pat in ("seniority_pattern", "leader_pattern"):
        try:
            re.compile(p[pat])
        except (re.error, KeyError) as e:
            errors.append(f"{pat}: {e}")
    labels = [l["label"] for l in p["lists"]]
    if len(set(labels)) != len(labels):
        errors.append("list labels must be unique")
    for l in p["lists"]:
        if l.get("source") not in SOURCES:
            errors.append(f"list {l.get('label')}: source must be one of {sorted(SOURCES)}")
    for x in p["lists"] + p["stages"]:
        if x.get("color") not in COLORS:
            errors.append(f"{x.get('label') or x.get('name')}: color must be one of {sorted(COLORS)}")
    names = [s["name"] for s in p["stages"]]
    if p.get("default_stage") not in names:
        errors.append("default_stage must be one of the stages")
    for e in p.get("former_employers", []):
        if not re.fullmatch(r"\d{4}-\d{2}", str(e.get("left", ""))) or not e.get("name"):
            errors.append(f"former employer {e}: needs name and left as YYYY-MM")
    if errors:
        sys.exit("Fix these in profile.json:\n- " + "\n- ".join(errors))
    print("profile.json looks good.")


if __name__ == "__main__":
    main()
