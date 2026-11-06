"""Small command line for changing data/crm.json: used by /process-notes. The app reloads by itself.

  crm.py notes
  crm.py find "name"
  crm.py set <id> [--list L] [--score N] [--stage S] [--signal TEXT] [--line LANG TEXT]
  crm.py ignore <id>
  crm.py done <id> <note_id> "what changed"
"""
import argparse
import json
from datetime import datetime, timezone

from common import CRM, norm, write_json_atomic


def load():
    return json.loads(CRM.read_text(encoding="utf-8"))


def get(d, cid):
    for c in d["contacts"]:
        if c["id"] == cid:
            return c
    raise SystemExit(f"No contact {cid}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("notes")
    f = sub.add_parser("find"); f.add_argument("name")
    s = sub.add_parser("set")
    s.add_argument("id"); s.add_argument("--list"); s.add_argument("--score"); s.add_argument("--stage")
    s.add_argument("--signal"); s.add_argument("--line", nargs=2, metavar=("LANG", "TEXT"))
    i = sub.add_parser("ignore"); i.add_argument("id")
    n = sub.add_parser("done"); n.add_argument("id"); n.add_argument("note_id"); n.add_argument("result")
    a = ap.parse_args()
    d = load()
    now = datetime.now(timezone.utc).isoformat()

    if a.cmd == "notes":
        for c in d["contacts"]:
            for x in c.get("classNotes", []):
                if x.get("status") != "done":
                    print(f"{c['id']} | {c['name']} | {c.get('role', '')} at {c.get('company', '')} | "
                          f"list: {(c.get('net') or {}).get('list', 'Unclassified')} | note {x['id']}: {x['text']}")
        return
    if a.cmd == "find":
        q = norm(a.name)
        for c in d["contacts"]:
            if q in norm(c["name"]):
                print(c["id"], "|", c["name"], "|", c.get("role", ""), "|", c.get("company", ""))
        return

    c = get(d, a.id)
    if a.cmd == "set":
        net = c.setdefault("net", {"list": "", "score": "", "lines": {}}) if (a.list or a.score or a.signal or a.line) else c.get("net")
        if a.list is not None:
            net["list"] = a.list
        if a.score is not None:
            net["score"] = a.score
        if a.signal:
            net["signals"] = "; ".join(filter(None, [net.get("signals"), a.signal]))
        if a.line:
            net.setdefault("lines", {})[a.line[0]] = a.line[1]
        if a.stage:
            c["stage"] = a.stage
        if net is not None:
            c["netLocked"] = True  # A later export must not undo this
    elif a.cmd == "ignore":
        c.pop("net", None)
        c["tags"] = sorted(set(c.get("tags", [])) | {"ignore"})
    elif a.cmd == "done":
        for x in c.get("classNotes", []):
            if x["id"] == a.note_id:
                x.update(status="done", doneAt=now[:10], result=a.result)
                break
        else:
            raise SystemExit(f"No note {a.note_id}")
    c["updatedAt"] = now
    write_json_atomic(CRM, d)
    print("Saved.")


if __name__ == "__main__":
    main()
