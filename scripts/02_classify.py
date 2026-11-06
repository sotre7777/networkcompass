"""Step 2: match every title against the profile's categories.

First match wins, in profile order. output/_work/overrides.csv (contact_id, category, note)
wins over the rules; an empty category means "not relevant".
Writes output/_work/classified.csv. With --review, prints titles for reading by hand.
"""
import re
import sys

import pandas as pd

from common import WORK, profile


def main() -> None:
    p = profile()
    c = pd.read_csv(WORK / "enriched.csv", dtype=str, keep_default_na=False)
    cats = [(x["id"], x["kind"], re.compile("|".join(x["match"]), re.I)) for x in p["categories"] if x.get("match")]
    ignore = re.compile("|".join(p.get("ignore_titles", [])) or r"$^", re.I)
    senior = re.compile(p["seniority_pattern"], re.I)

    def classify(title):
        if not title or ignore.search(title):
            return "", ""
        for cid, kind, pat in cats:
            if pat.search(title):
                return cid, kind
        return "", ""

    hits = c["title"].map(classify)
    c["category"], c["kind"] = hits.str[0], hits.str[1]
    c["senior"] = c["title"].map(lambda t: bool(senior.search(t)))
    kinds = {x["id"]: x["kind"] for x in p["categories"]}
    ov = WORK / "overrides.csv"
    if ov.exists():
        o = pd.read_csv(ov, dtype=str, keep_default_na=False).set_index("contact_id")
        hit = c["contact_id"].isin(o.index)
        c.loc[hit, "category"] = c.loc[hit, "contact_id"].map(o["category"])
        c.loc[hit, "kind"] = c.loc[hit, "category"].map(kinds).fillna("")
        print(f"Applied {hit.sum()} hand corrections")
    named = c["title"] != ""
    print(f"Scorable (has a title): {named.sum():,}; matched a category: {(c['category'] != '').sum():,}")
    print(c.loc[c["category"] != "", "category"].value_counts().to_string())
    c.to_csv(WORK / "classified.csv", index=False)

    if "--review" in sys.argv:
        for cid, g in c[c["category"] != ""].groupby("category"):
            print(f"\n===== {cid} ({len(g)})")
            for _, x in g.iterrows():
                print(x["contact_id"], "|", x["company"][:32], "|", x["title"][:80])
        rest = c[(c["category"] == "") & (c["senior"] | (c["direct"] == "1"))]
        print(f"\n===== senior or warm, no category ({len(rest)})")
        for _, x in rest.iterrows():
            print(x["contact_id"], "|", x["company"][:32], "|", x["title"][:80])


if __name__ == "__main__":
    main()
