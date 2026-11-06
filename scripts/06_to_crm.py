"""Step 6: merge the result into data/crm.json, which the app reads.

Backs up first. For people already there it updates only company, role, LinkedIn fields and the
network section, and records job changes. Stages, notes, touchpoints and reminders are never touched.
Every connection comes in; anyone not on a list shows as Unclassified.
"""
import json
import shutil
from datetime import datetime, timezone

import pandas as pd

from common import CRM, DATA, OUT, WORK, norm, norm_url, profile, write_json_atomic


def default_config(p):
    o = p["outreach"]
    return {"lists": [{"name": x["label"], "color": x["color"], "source": x["source"]} for x in p["lists"]],
            "stages": p["stages"], "defaultStage": p["default_stage"],
            "asks": o["asks"], "statuses": o["statuses"], "sentStatus": o["sent_status"],
            "repliedStatuses": o["replied_statuses"], "talkedStatus": o["talked_status"],
            "referralStatus": o["referral_status"], "proposalAsk": o["proposal_ask"],
            "proposalLabel": o["proposal_label"], "leaderPattern": p["leader_pattern"]}


def main() -> None:
    p = profile()
    now = datetime.now(timezone.utc).isoformat()
    today = now[:10]
    if CRM.exists():
        shutil.copy(CRM, DATA / f"crm-backup-{now[:19].replace(':', '')}.json")
        crm = json.loads(CRM.read_text(encoding="utf-8"))
    else:
        crm = {"version": 2, "config": default_config(p), "contacts": []}
    conf = crm.setdefault("config", default_config(p))
    # The app's Settings own lists and stages after the first run; only add what is new
    have = {x.get("source") for x in conf["lists"]}
    conf["lists"] += [{"name": x["label"], "color": x["color"], "source": x["source"]} for x in p["lists"] if x["source"] not in have]
    # A list renamed in the app keeps its new name: the analysis finds it by source
    shown = {x.get("source"): x["name"] for x in conf["lists"]}
    name_for = {x["label"]: shown[x["source"]] for x in p["lists"]}

    e = pd.read_csv(WORK / "enriched.csv", dtype=str, keep_default_na=False)
    sel = pd.read_csv(OUT / "selection.csv", dtype=str, keep_default_na=False).set_index("contact_id")
    lf = WORK / "lines.json"
    lines = json.loads(lf.read_text(encoding="utf-8")) if lf.exists() else {}

    by_url = {norm_url(c.get("linkedin")): c for c in crm["contacts"] if c.get("linkedin")}
    by_name = {norm(c["name"]): c for c in crm["contacts"] if not c.get("linkedin")}
    added = changed = 0
    for r in e.itertuples():
        c = by_url.get(norm_url(r.url)) or by_name.get(norm(r.name))
        job = {"company": r.company, "position": r.title}
        if c is None:
            c = {"id": r.contact_id, "name": r.name, "company": r.company, "role": r.title, "email": r.email,
                 "phone": "", "linkedin": r.url, "stage": conf["defaultStage"], "tags": ["linkedin"], "notes": "",
                 "nextFollowUp": "", "interactions": [], "changes": [], "classNotes": [],
                 "connectedOn": r.connected_on, "createdAt": now}
            crm["contacts"].append(c)
            added += 1
        else:
            prev = c.get("li")
            if prev and prev != job:
                c.setdefault("changes", []).append({"id": now[11:19] + r.contact_id[-6:], "date": today, "from": prev, "to": job, "seen": False})
                changed += 1
            c["company"], c["role"] = r.company, r.title
            c["linkedin"] = c.get("linkedin") or r.url
            c["email"] = c.get("email") or r.email
        c["li"] = job
        c["updatedAt"] = now
        if c.get("netLocked") or "ignore" in c.get("tags", []):
            continue  # moved by hand in the app, or told to stay off the lists
        if r.contact_id in sel.index:
            s = sel.loc[r.contact_id]
            ln = lines.get(r.contact_id, {})
            size = "size unknown" if s["size_est"] == "size unknown" else f"{s['size_est']} (inferred: {s['size_basis']})"
            for flag in filter(None, s["flags"].split(";")):
                size += f" (inferred: {flag.strip()})"
            c["net"] = {"list": name_for.get(s["list"], s["list"]), "rank": int(s["rank"]), "score": s["score"], "category": s["label"],
                        "why": ln.get("why", ""), "size": size, "signals": s["signals"], "order": s["order"],
                        "lines": {k: v for k, v in ln.items() if k != "why"}}
        elif c.get("net") and not c.get("interactions"):
            del c["net"]
    write_json_atomic(CRM, crm)
    print(f"data/crm.json: {len(crm['contacts']):,} contacts, {added:,} new, {changed} job changes")


if __name__ == "__main__":
    main()
