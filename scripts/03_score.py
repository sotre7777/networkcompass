"""Step 3: place each person in a size band and score them 1 to 5.

Inputs in output/_work: classified.csv, company_sizes.tsv, optional unit_sizes.tsv.
Every band is an inference. A person with no size basis is "unknown" and is not guessed at.
"""
import re

import pandas as pd

from common import WORK, profile

SOLO = re.compile(r"self[- ]?employed|freelanc|independent|retired", re.I)
OWNER = re.compile(r"owner|founder", re.I)


def tsv(name):
    f = WORK / name
    if not f.exists():
        return None
    return pd.read_csv(f, sep="\t", dtype=str, keep_default_na=False)


def base_score(r):
    k, b = r["kind"], r["band"]
    if r["referral_only"] == "True":
        return 4 if (k == "decision" or r["unit"]) else (3 if r["senior"] == "True" else 0)
    if k == "decision":
        return {"in": 5, "near_low": 4, "near_high": 4, "above": 3}.get(b, 2)
    if k in ("door", "investor"):
        return 4
    if k == "low":
        return 2
    if not k and r["proxy_moved"] == "True" and r["senior"] == "True":
        # A likely former colleague in a senior seat: a referral source through the proxy alone
        return {"in": 4, "near_low": 3, "near_high": 3}.get(b, 2)
    return 0


def final(r):
    s = r["base"]
    if s >= 3:
        if r["direct"] == "1":
            s += 1
        elif r["proxy_moved"] == "True" and s == 3 and r["kind"]:
            s += 1  # The proxy lifts 3 to 4; a 5 still needs band fit or a direct signal
    if r["excluded"] == "True" or r["in_talks"] == "True":
        s = 0
    return min(5, s)


def main() -> None:
    c = pd.read_csv(WORK / "classified.csv", dtype=str, keep_default_na=False)
    sizes = tsv("company_sizes.tsv")
    if sizes is None:
        raise SystemExit("No output/_work/company_sizes.tsv yet: step 3 of /mine-network writes it.")
    sizes = sizes.drop_duplicates("company").set_index("company")
    units = tsv("unit_sizes.tsv")
    units = units.set_index("contact_id") if units is not None else pd.DataFrame()

    def place(r):
        if r["contact_id"] in units.index:
            u = units.loc[r["contact_id"]]
            parent = sizes.loc[r["company"], "est"] if r["company"] in sizes.index else "size unknown"
            return u["band"], f"Unit: {u['unit']}, {u['est']}", f"{u['basis']}; parent {parent}", "", u["unit"]
        if r["company"] in sizes.index:
            s = sizes.loc[r["company"]]
            return s["band"], s["est"], s["basis"], s["flags"], ""
        if SOLO.search(r["company"]) or (r["kind"] in ("decision", "door") and OWNER.search(r["title"])):
            return "below", "small", "self-employed or owner-led", "", ""
        return "unknown", "size unknown", "", "", ""

    c[["band", "size_est", "size_basis", "flags", "unit"]] = c.apply(place, axis=1, result_type="expand")
    c["base"] = c.apply(base_score, axis=1)
    c["score"] = c.apply(final, axis=1)
    known = c[(c["company"] != "") & (c["band"] != "unknown")]
    print("Bands (inferred):", c["band"].value_counts().to_dict())
    print("Score counts:", c["score"].value_counts().sort_index(ascending=False).to_dict())
    if len(known):
        print(f"In the target band: {(known['band'] == 'in').sum()} of {len(known)} connections I could size")
    c.to_csv(WORK / "scored.csv", index=False)


if __name__ == "__main__":
    main()
