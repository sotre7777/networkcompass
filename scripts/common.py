"""Shared helpers for the pipeline. Run scripts from the repo root."""
from __future__ import annotations

import hashlib
import io
import json
import os
import re
import sys
import tempfile
import time
import unicodedata
from pathlib import Path

import pandas as pd

# Windows consoles default to an older encoding that cannot print every name
for stream in (sys.stdout, sys.stderr):
    if hasattr(stream, "reconfigure"):
        stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(os.environ.get("NC_ROOT", Path(__file__).resolve().parent.parent))
EXPORT = ROOT / "export"
OUT = ROOT / "output"
WORK = OUT / "_work"
DATA = ROOT / "data"
CRM = DATA / "crm.json"


def profile() -> dict:
    p = ROOT / "profile.json"
    if not p.exists():
        raise SystemExit("No profile.json yet. Run /setup-network in Claude Code first.")
    return json.loads(p.read_text(encoding="utf-8"))


def norm(s) -> str:
    """Lowercase, no accents, letters and digits only: for matching names."""
    if pd.isna(s):
        return ""
    s = unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9 ]", "", s.lower()).strip()


def norm_url(u) -> str:
    if pd.isna(u):
        return ""
    u = re.sub(r"^https?://", "", str(u).lower().strip().rstrip("/"))
    return re.sub(r"^www\.", "", u)


def contact_id(url: str, name: str) -> str:
    """Stable across exports: from the profile URL, or the name when there is none."""
    key = norm_url(url).rsplit("/", 1)[-1] or norm(name)
    slug = re.sub(r"[^a-z0-9-]", "", key)
    return "li-" + (slug or hashlib.sha1(key.encode()).hexdigest()[:12])


def read_csv(path: Path) -> pd.DataFrame:
    """LinkedIn sometimes puts a Notes block above the real header."""
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()
    start = 0
    if lines and lines[0].startswith("Notes:"):
        for i, line in enumerate(lines):
            if i > 0 and line.strip() == "":
                start = i + 1
                break
    return pd.read_csv(io.StringIO("\n".join(lines[start:])), dtype=str)


def word_re(words) -> re.Pattern | None:
    """Whole-word, case-insensitive match for any of the given company or term names."""
    words = [w for w in words if w]
    if not words:
        return None
    return re.compile(r"(?<![a-z0-9])(" + "|".join(re.escape(w) for w in words) + r")(?![a-z0-9])", re.I)


def write_json_atomic(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False)
    for attempt in range(20):
        try:
            os.replace(tmp, path)
            return
        except PermissionError:  # Windows refuses while another program is reading the file
            if attempt == 19:
                raise
            time.sleep(0.1)


def default_config(p: dict) -> dict:
    """The app's settings, taken from a profile the first time the data file is made."""
    o = p["outreach"]
    return {"lists": [{"name": x["label"], "color": x["color"], "source": x["source"]} for x in p["lists"]],
            "stages": p["stages"], "defaultStage": p["default_stage"],
            "asks": o["asks"], "statuses": o["statuses"], "sentStatus": o["sent_status"],
            "repliedStatuses": o["replied_statuses"], "talkedStatus": o["talked_status"],
            "referralStatus": o["referral_status"], "proposalAsk": o["proposal_ask"],
            "proposalLabel": o["proposal_label"], "leaderPattern": p["leader_pattern"]}


BAND_RANK = {"in": 0, "near_low": 1, "near_high": 1, "above": 2, "below": 3, "unknown": 3}
