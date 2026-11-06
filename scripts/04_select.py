"""Step 4: fill each list in the profile, rank it, and set the contact order.

Writes output/selection.csv, output/worklist.csv (who needs an opening line) and output/gaps.md.
"""
import json
import re

import pandas as pd

from common import BAND_RANK, CRM, OUT, WORK, norm_url, profile


def ignored_urls():
    if not CRM.exists():
        return set()
    d = json.loads(CRM.read_text(encoding="utf-8"))
    return {norm_url(c.get("linkedin")) for c in d["contacts"] if "ignore" in c.get("tags", [])}


def main() -> None:
    p = profile()
    c = pd.read_csv(WORK / "scored.csv", dtype=str, keep_default_na=False)
    c["score"] = c["score"].astype(int)
    c = c[~c["url"].map(norm_url).isin(ignored_urls() - {""})]
    c["br"] = c["band"].map(BAND_RANK).fillna(3)
    c["dw"] = c["direct"].astype(int)
    labels = {x["id"]: x["label"] for x in p["categories"]}
    c["label"] = c["category"].map(labels).fillna("")
    c.loc[(c["label"] == "") & (c["proxy_moved"] == "True") & (c["score"] > 0), "label"] = "Former colleague"

    def pri(r):
        if r["kind"] == "decision":
            return 1 if r["band"] in ("in", "near_low", "near_high") or r["unit"] else 3
        return 2 if r["kind"] == "door" or r["senior"] == "True" else 4

    c["pri"] = c.apply(pri, axis=1)
    key, asc = ["score", "pri", "dw", "br"], [False, True, False, True]
    leader = re.compile(p["leader_pattern"], re.I)
    is_lead = c["title"].map(lambda t: bool(leader.search(t)) and "assistant" not in t.lower())
    pool = (c["excluded"] == "False") & (c["referral_only"] == "False") & (c["in_talks"] == "False")

    taken, rows = set(), []
    for lst in p["lists"]:
        src = lst["source"]
        if src == "matches":
            m = c[pool & (c["score"] >= 4) & (c["kind"] != "investor")].sort_values(key, ascending=asc)
            fives, fours = m[m["score"] == 5], m[m["score"] == 4]
            cap = lst.get("cap_4", 30)
            print(f"{lst['label']}: {len(fives)} fives, {len(fours)} fours (showing {min(cap, len(fours))}, "
                  f"{max(0, len(fours) - cap)} more exist)")
            s = pd.concat([fives, fours.head(cap)])
        elif src == "investors":
            s = c[pool & (c["score"] >= 4) & (c["kind"] == "investor")].sort_values(key, ascending=asc)
        elif src == "referral_companies":
            s = c[(c["referral_only"] == "True") & (c["excluded"] == "False") & (c["score"] >= 3)].sort_values(key, ascending=asc)
        elif src == "in_talks_leaders":
            s = c[(c["in_talks"] == "True") & is_lead].sort_values(["company", "name"])
        elif src == "in_talks_rest":
            s = c[(c["in_talks"] == "True") & ~is_lead].sort_values(["company", "name"])
        else:
            continue  # warm is filled last: it takes who is left
        s = s[~s["contact_id"].isin(taken)]
        taken |= set(s["contact_id"])
        rows.append(s.assign(list=lst["label"]))
    for lst in p["lists"]:
        if lst["source"] == "warm":
            s = c[pool & (c["dw"] == 1) & c["band"].isin(["in", "near_low", "near_high"]) & ~c["contact_id"].isin(taken)].copy()
            s["strong"] = s["signals"].str.contains("recommend|endorse").astype(int)
            s = s.sort_values(["br", "strong"], ascending=[True, False]).head(lst.get("cap", 20))
            taken |= set(s["contact_id"])
            rows.append(s.assign(list=lst["label"]))

    sel = pd.concat(rows) if rows else c.head(0).assign(list="")
    sel["rank"] = sel.groupby("list", sort=False).cumcount() + 1
    # Several people at one company: start with the strongest, hold the others
    sel["order"] = ""
    talks = sel["in_talks"] == "True"
    for comp, g in sel[(sel["company"] != "") & ~talks & (sel["kind"] != "")].groupby("company"):
        if len(g) < 2:
            continue
        first = g.sort_values(["score", "dw"], ascending=False).index[0]
        sel.loc[g.index, "order"] = "hold until the first replies"
        sel.loc[first, "order"] = "contact first"
    cols = ["contact_id", "list", "rank", "score", "label", "name", "title", "company", "size_est", "size_basis",
            "flags", "signals", "order", "in_talks"]
    sel[cols].to_csv(OUT / "selection.csv", index=False)
    sel[~talks][cols].to_csv(OUT / "worklist.csv", index=False)

    lines = ["# Gaps", "", "Every size and band here is inferred. Check before writing to anyone.", "", "| List | People |", "|---|---|"]
    lines += [f"| {k} | {v} |" for k, v in sel["list"].value_counts().items()]
    known = c[(c["company"] != "") & (c["band"] != "unknown") & pool]
    if len(known):
        share = (known["band"] == "in").mean() * 100
        lines += ["", f"**{(known['band'] == 'in').sum()} of the {len(known)} connections I could size are in your target band ({share:.0f}%).** "
                  f"{(c['band'] == 'unknown').sum()} could not be sized."]
        if share < 15:
            lines += ["", "That is thin. This network will work mostly through referrals, so plan a second route alongside it."]
    (OUT / "gaps.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(sel["list"].value_counts().to_string())
    print(f"Need opening lines: {(~talks).sum()}. Wrote output/worklist.csv and output/gaps.md")


if __name__ == "__main__":
    main()
