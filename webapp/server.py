"""Network Compass in your browser, for Windows, Mac and Linux.

Runs on this computer only and uses data/crm.json, the same file as the Mac app.
Needs nothing beyond Python. Start with: python webapp/server.py
"""
import argparse
import json
import secrets
import sys
import threading
import webbrowser
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
from common import CRM, ROOT, default_config, write_json_atomic  # noqa: E402

TOKEN = secrets.token_urlsafe(24)
LOCK = threading.Lock()
EDITABLE = {"name", "company", "role", "email", "phone", "linkedin", "stage", "tags", "notes", "nextFollowUp", "net", "netLocked", "changes"}


def now():
    return datetime.now(timezone.utc).isoformat()


def load():
    if not CRM.exists():
        src = ROOT / "profile.json"
        if not src.exists():
            src = ROOT / "profiles" / "opportunity.json"
        write_json_atomic(CRM, {"version": 2, "config": default_config(json.loads(src.read_text(encoding="utf-8"))), "contacts": []})
    return json.loads(CRM.read_text(encoding="utf-8"))


def find(d, cid):
    for c in d["contacts"]:
        if c["id"] == cid:
            return c
    raise KeyError(cid)


def update_contact(d, b):
    """Change only what was asked, on the latest file, so edits by Claude are never overwritten."""
    c = find(d, b["id"])
    for k, v in b.get("set", {}).items():
        if k in EDITABLE:
            c[k] = v
    for field, item in b.get("append", {}).items():
        if field in ("interactions", "classNotes"):
            c.setdefault(field, []).append(item)
    for field, item_id in b.get("remove", {}).items():
        if field in ("interactions", "classNotes"):
            c[field] = [x for x in c.get(field, []) if x.get("id") != item_id]
    c["updatedAt"] = now()


def add_contact(d, b):
    c = {k: v for k, v in b["contact"].items() if k in EDITABLE}
    c.update(id="c-" + secrets.token_hex(4), interactions=[], changes=[], classNotes=[], createdAt=now(), updatedAt=now())
    d["contacts"].append(c)
    return c["id"]


def update_config(d, b):
    conf = d["config"]
    for k in ("lists", "stages", "defaultStage"):
        if k in b.get("config", {}):
            conf[k] = b["config"][k]
    old, new = b.get("renameList") or (None, None)
    gone = b.get("deleteList")
    for c in d["contacts"]:
        net = c.get("net")
        if net and old and net.get("list") == old:
            net["list"] = new
        if net and gone and net.get("list") == gone:
            del c["net"]
    old, new = b.get("renameStage") or (None, None)
    gone = b.get("deleteStage")
    for c in d["contacts"]:
        if old and c.get("stage") == old:
            c["stage"] = new
        if gone and c.get("stage") == gone:
            c["stage"] = conf["defaultStage"]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # Requests hold names: keep them out of the terminal

    def trusted(self):
        # Only this page, on this computer: blocks other websites from reaching your contacts
        host = self.headers.get("Host", "").split(":")[0]
        return host in ("127.0.0.1", "localhost") and secrets.compare_digest(self.headers.get("X-Token", ""), TOKEN)

    def send(self, code, body, kind="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            if self.headers.get("Host", "").split(":")[0] not in ("127.0.0.1", "localhost"):
                return self.send(403, {"error": "forbidden"})
            page = (HERE / "index.html").read_text(encoding="utf-8").replace("__TOKEN__", TOKEN)
            return self.send(200, page.encode("utf-8"), "text/html; charset=utf-8")
        if not self.trusted():
            return self.send(403, {"error": "forbidden"})
        with LOCK:
            d = load()
        if self.path == "/api/data":
            return self.send(200, {"data": d, "stamp": CRM.stat().st_mtime, "file": str(CRM)})
        if self.path == "/api/stamp":
            return self.send(200, {"stamp": CRM.stat().st_mtime})
        self.send(404, {"error": "not found"})

    def do_POST(self):
        if not self.trusted():
            return self.send(403, {"error": "forbidden"})
        size = int(self.headers.get("Content-Length", 0))
        if size > 2_000_000:
            return self.send(413, {"error": "too large"})
        b = json.loads(self.rfile.read(size) or b"{}")
        try:
            with LOCK:
                d, out = load(), {}
                if self.path == "/api/update":
                    update_contact(d, b)
                elif self.path == "/api/add":
                    out["id"] = add_contact(d, b)
                elif self.path == "/api/delete":
                    d["contacts"] = [c for c in d["contacts"] if c["id"] != b["id"]]
                elif self.path == "/api/config":
                    update_config(d, b)
                else:
                    return self.send(404, {"error": "not found"})
                write_json_atomic(CRM, d)
        except KeyError as e:
            return self.send(404, {"error": f"not found: {e}"})
        self.send(200, out)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--no-browser", action="store_true")
    a = ap.parse_args()
    try:
        srv = ThreadingHTTPServer(("127.0.0.1", a.port), Handler)
    except OSError:
        srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)  # Port in use: take a free one
    url = f"http://127.0.0.1:{srv.server_address[1]}/"
    load()
    print(f"Network Compass is running at {url}", flush=True)
    print("Keep this window open while you use it. Close it to stop.", flush=True)
    if not a.no_browser:
        webbrowser.open(url)
    srv.serve_forever()


if __name__ == "__main__":
    main()
