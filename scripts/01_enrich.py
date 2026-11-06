"""Step 1: load Connections.csv and attach warmth and overlap signals to every row.

Writes output/_work/enriched.csv. Prints counts, never names.
"""
import pandas as pd

from common import EXPORT, WORK, contact_id, norm, norm_url, profile, read_csv, word_re


def company_mask(series, names):
    pat = word_re(names)
    if pat is None:
        return pd.Series(False, index=series.index)
    return series.fillna("").map(lambda s: bool(pat.search(s)))


def main() -> None:
    p = profile()
    if not (EXPORT / "Connections.csv").exists():
        raise SystemExit("No export/Connections.csv. See docs/linkedin-export.md.")
    print("Files in export:", sum(1 for f in EXPORT.rglob("*") if f.is_file()))
    raw = (EXPORT / "Connections.csv").read_text(encoding="utf-8-sig").splitlines()
    header = next((i for i, l in enumerate(raw) if l.startswith("First Name")), 0)
    c = pd.read_csv(EXPORT / "Connections.csv", skiprows=header, dtype=str)
    c["name"] = (c["First Name"].fillna("") + " " + c["Last Name"].fillna("")).str.strip()
    total = len(c)
    c = c[c["name"] != ""].copy()
    print(f"Connections: {total:,} rows, {total - len(c)} hidden profiles (no name, cannot be scored)")
    c["contact_id"] = [contact_id(u, n) for u, n in zip(c["URL"].fillna(""), c["name"])]
    c = c.drop_duplicates("contact_id")
    c["connected"] = pd.to_datetime(c["Connected On"], format="%d %b %Y", errors="coerce")
    c["name_key"] = c["name"].map(norm)
    c["url_key"] = c["URL"].map(norm_url)
    c["signals"] = [[] for _ in range(len(c))]
    c["direct"] = 0
    counts = c["name_key"].value_counts()

    def add(mask, label, warm=True):
        for i in c.index[mask]:
            if label not in c.at[i, "signals"]:
                c.at[i, "signals"].append(label)
        if warm:
            c.loc[mask, "direct"] = 1

    for fname, label in [("Recommendations_Received.csv", "recommended you"),
                         ("Recommendations_Given.csv", "you recommended them")]:
        if not (EXPORT / fname).exists():
            print(f"{fname}: not in export")
            continue
        r = read_csv(EXPORT / fname)
        keys = (r["First Name"].fillna("") + " " + r["Last Name"].fillna("")).map(norm)
        for k in keys:
            add(c["name_key"] == k, label + (" (uncertain name match)" if counts.get(k, 0) > 1 else ""))
        print(f"{fname}: {len(r)} rows, {keys.isin(c['name_key']).sum()} matched")

    for fname, col, label in [("Endorsement_Received_Info.csv", "Endorser Public Url", "endorsed you"),
                              ("Endorsement_Given_Info.csv", "Endorsee Public Url", "you endorsed them")]:
        if not (EXPORT / fname).exists():
            print(f"{fname}: not in export")
            continue
        e = read_csv(EXPORT / fname)
        urls = set(e[col].map(norm_url)) - {""}
        m = c["url_key"].isin(urls)
        add(m, label)
        print(f"{fname}: {len(urls)} people, {m.sum()} matched")

    if (EXPORT / "Invitations.csv").exists():
        inv = read_csv(EXPORT / "Invitations.csv")
        done = 0
        for _, r in inv.iterrows():
            out = r.get("Direction") == "OUTGOING"
            url = norm_url(r.get("inviteeProfileUrl" if out else "inviterProfileUrl"))
            m = (c["url_key"] == url) if url else pd.Series(False, index=c.index)
            if not m.any():
                m = c["name_key"] == norm(r.get("To" if out else "From"))
            if m.any():
                add(m, "recent invitation you sent" if out else "recent invitation to you")
                done += 1
        print(f"Invitations.csv: {len(inv)} rows, {done} matched")

    co = c["Company"]
    if (EXPORT / "Company Follows.csv").exists():
        follows = set(read_csv(EXPORT / "Company Follows.csv")["Organization"].map(norm)) - {""}
        m = co.map(norm).isin(follows)
        add(m, "you follow their company", warm=False)
        print(f"Company Follows.csv: {m.sum()} connections at a followed company")

    if p.get("use_job_files"):
        names = set()
        for f in list((EXPORT / "Jobs").glob("Saved Jobs*.csv")) + list((EXPORT / "Jobs").glob("Job Applications*.csv")):
            names |= set(read_csv(f)["Company Name"].map(norm)) - {""}
        m = co.map(norm).isin(names)
        add(m, "you saved or applied to a job there", warm=False)
        print(f"Saved jobs and applications: {m.sum()} connections at those companies")

    c["proxy_moved"] = False
    for e in p.get("former_employers", []):
        at = company_mask(co, [e["name"]])
        left = pd.Timestamp(e["left"] + "-01") + pd.offsets.MonthEnd(1)
        start = pd.Timestamp(e["start"] + "-01") if e.get("start") else pd.Timestamp("1900-01-01")
        era = c["connected"].between(start, left)
        moved = era & ~at
        add(moved, f"(proxy: {e['name']} era) connected during your time there, now elsewhere", warm=False)
        add(era & at, f"(proxy: {e['name']} era) still there", warm=False)
        c.loc[moved, "proxy_moved"] = True
        print(f"{e['name']} proxy: {moved.sum():,} now elsewhere, {(era & at).sum():,} still there")

    excluded = list(p.get("excluded_companies", [])) + ([p["current_employer"]] if p.get("current_employer") else [])
    c["excluded"] = company_mask(co, excluded)
    c["in_talks"] = company_mask(co, p.get("in_talks_companies", []))
    c["referral_only"] = company_mask(co, p.get("referral_only_companies", []))
    print(f"Excluded {c['excluded'].sum()}, in talks {c['in_talks'].sum()}, referral-only {c['referral_only'].sum()}")
    print(f"Direct warmth signal: {c['direct'].sum()}")

    c["signals"] = c["signals"].map("; ".join)
    WORK.mkdir(parents=True, exist_ok=True)
    c = c.rename(columns={"Company": "company", "Position": "title", "URL": "url", "Email Address": "email", "Connected On": "connected_on"})
    c[["contact_id", "name", "url", "email", "company", "title", "connected_on", "connected", "signals", "direct",
       "proxy_moved", "excluded", "in_talks", "referral_only"]].to_csv(WORK / "enriched.csv", index=False)


if __name__ == "__main__":
    main()
