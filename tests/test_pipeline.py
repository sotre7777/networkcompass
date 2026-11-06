"""End-to-end test on a fake export, for both lenses. Run: python3 -m unittest discover tests"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SIZES = {"Northwind Traders": ("~800", "in"), "Acme Robotics": ("~1,200", "in"), "Bluebird Health": ("~300", "near_low"),
         "Harbor Logistics": ("~9,000", "near_high"), "Quill Software": ("~120", "below"), "Tidewater Energy": ("~50,000", "above"),
         "Granite Bank": ("~30,000", "above")}


class Pipeline(unittest.TestCase):
    def run_step(self, root, script, *args):
        env = dict(os.environ, NC_ROOT=str(root))
        r = subprocess.run([sys.executable, str(REPO / "scripts" / script), *args], env=env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        return r.stdout

    def build(self, lens):
        root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, root)
        subprocess.run([sys.executable, str(REPO / "tests/make_fake_export.py"), str(root / "export")], check=True, capture_output=True)
        p = json.loads((REPO / "profiles" / f"{lens}.json").read_text())
        p["owner"]["background"] = "Twenty years building teams."
        p["former_employers"] = [{"name": "Tidewater Energy", "start": "2012-01", "left": "2020-06"}]
        p["in_talks_companies"] = ["Fable Foods"]
        p["referral_only_companies"] = ["Granite Bank"]
        p["excluded_companies"] = ["Harbor Logistics"]
        (root / "profile.json").write_text(json.dumps(p))
        self.run_step(root, "validate_profile.py")
        self.run_step(root, "01_enrich.py")
        self.run_step(root, "02_classify.py", "--review")
        (root / "output/_work/company_sizes.tsv").write_text(
            "company\test\tband\tbasis\tflags\n" + "".join(f"{k}\t{v[0]}\t{v[1]}\ttest\t\n" for k, v in SIZES.items()))
        self.run_step(root, "03_score.py")
        self.run_step(root, "04_select.py")
        return root, p

    def crm(self, root):
        return json.loads((root / "data/crm.json").read_text())

    def test_both_lenses(self):
        for lens in ("job", "opportunity"):
            with self.subTest(lens=lens):
                root, p = self.build(lens)
                self.run_step(root, "06_to_crm.py")
                d = self.crm(root)
                self.assertEqual(len(d["contacts"]), 120)  # the hidden profile is left out
                self.assertEqual([s["name"] for s in d["config"]["stages"]], [s["name"] for s in p["stages"]])
                on_lists = [c for c in d["contacts"] if c.get("net")]
                self.assertTrue(on_lists)
                self.assertFalse([c for c in on_lists if c["company"] == "Harbor Logistics"], "excluded company on a list")
                talks = [c for c in on_lists if c["company"] == "Fable Foods"]
                self.assertTrue(talks and all(c["net"]["list"].startswith(("In talks", "In process")) for c in talks))
                ref = p["lists"][2]["label"]
                self.assertTrue(all(c["company"] == "Granite Bank" for c in on_lists if c["net"]["list"] == ref))

    def test_rerun_keeps_user_work(self):
        root, p = self.build("opportunity")
        self.run_step(root, "06_to_crm.py")
        d = self.crm(root)
        c = d["contacts"][0]
        c.update(stage="Assess", notes="Met at a conference", nextFollowUp="2030-01-01")
        c["interactions"] = [{"id": "a", "date": "2026-01-01", "type": "Call", "summary": "Spoke"}]
        c["classNotes"] = [{"id": "n", "date": "2026-01-01", "text": "Move them", "status": "open"}]
        c["li"] = {"company": "Old Co", "position": "Old role"}
        hand = {"id": "c-1", "name": "Hand Added", "company": "X", "role": "Y", "linkedin": "", "stage": "Prospect",
                "tags": [], "interactions": [], "classNotes": [], "changes": []}
        d["contacts"].append(hand)
        (root / "data/crm.json").write_text(json.dumps(d))
        self.run_step(root, "06_to_crm.py")
        d2 = self.crm(root)
        c2 = next(x for x in d2["contacts"] if x["id"] == c["id"])
        self.assertEqual((c2["stage"], c2["notes"], c2["nextFollowUp"]), ("Assess", "Met at a conference", "2030-01-01"))
        self.assertEqual(len(c2["interactions"]), 1)
        self.assertEqual(len(c2["classNotes"]), 1)
        self.assertEqual(len(c2["changes"]), 1, "job change not recorded")
        self.assertTrue(any(x["id"] == "c-1" for x in d2["contacts"]), "hand-added contact lost")
        self.assertTrue(list((root / "data").glob("crm-backup-*.json")), "no backup")

    def test_notes_cli_and_ignore_survives(self):
        root, p = self.build("opportunity")
        self.run_step(root, "06_to_crm.py")
        d = self.crm(root)
        c = next(x for x in d["contacts"] if x.get("net"))
        c["classNotes"] = [{"id": "n1", "date": "2026-01-01", "text": "Ignore", "status": "open"}]
        (root / "data/crm.json").write_text(json.dumps(d))
        self.assertIn("n1", self.run_step(root, "crm.py", "notes"))
        self.run_step(root, "crm.py", "ignore", c["id"])
        self.run_step(root, "crm.py", "done", c["id"], "n1", "Left off the lists")
        self.run_step(root, "04_select.py")
        self.run_step(root, "06_to_crm.py")
        c2 = next(x for x in self.crm(root)["contacts"] if x["id"] == c["id"])
        self.assertNotIn("net", c2)
        self.assertEqual(c2["classNotes"][0]["status"], "done")

    def test_renamed_list_survives_rerun(self):
        root, p = self.build("opportunity")
        self.run_step(root, "06_to_crm.py")
        d = self.crm(root)
        for x in d["config"]["lists"]:
            if x["name"] == "Matches":
                x["name"] = "Top people"
        for c in d["contacts"]:
            if (c.get("net") or {}).get("list") == "Matches":
                c["net"]["list"] = "Top people"
        (root / "data/crm.json").write_text(json.dumps(d))
        self.run_step(root, "06_to_crm.py")
        d2 = self.crm(root)
        names = [x["name"] for x in d2["config"]["lists"]]
        self.assertIn("Top people", names)
        self.assertNotIn("Matches", names)
        self.assertFalse([c for c in d2["contacts"] if (c.get("net") or {}).get("list") == "Matches"])

    def test_moved_by_hand_stays(self):
        root, p = self.build("opportunity")
        self.run_step(root, "06_to_crm.py")
        c = next(x for x in self.crm(root)["contacts"] if x.get("net"))
        self.run_step(root, "crm.py", "set", c["id"], "--list", "Warm network")
        self.run_step(root, "06_to_crm.py")
        c2 = next(x for x in self.crm(root)["contacts"] if x["id"] == c["id"])
        self.assertEqual(c2["net"]["list"], "Warm network")


class WebApp(unittest.TestCase):
    """The browser app's server: saves, keeps others' edits, and refuses outsiders."""

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        shutil.copytree(REPO / "profiles", self.root / "profiles")
        env = dict(os.environ, NC_ROOT=str(self.root), PYTHONUNBUFFERED="1")
        self.proc = subprocess.Popen([sys.executable, str(REPO / "webapp/server.py"), "--port", "0", "--no-browser"],
                                     env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        self.addCleanup(self.proc.stdout.close)
        self.addCleanup(self.proc.wait)
        self.addCleanup(self.proc.terminate)
        self.base = self.proc.stdout.readline().split()[-1].rstrip("/")
        page = urllib.request.urlopen(self.base + "/").read().decode()
        self.token = re.search(r'TOKEN="([^"]+)"', page).group(1)

    def call(self, path, body=None, token=None, host=None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(self.base + path, data=data)
        req.add_header("X-Token", self.token if token is None else token)
        if host:
            req.add_header("Host", host)
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())

    def test_add_update_and_claude_edit_in_between(self):
        cid = self.call("/api/add", {"contact": {"name": "Test Person", "stage": "Prospect"}})["id"]
        crm = self.root / "data/crm.json"
        d = json.loads(crm.read_text(encoding="utf-8"))
        d["contacts"][0]["notes"] = "Written by Claude while the app is open"
        crm.write_text(json.dumps(d), encoding="utf-8")
        self.call("/api/update", {"id": cid, "set": {"stage": "Assess", "nextFollowUp": "2030-01-01"},
                                  "append": {"interactions": {"id": "i1", "date": "2026-01-01", "type": "Call", "summary": "Spoke"}}})
        c = self.call("/api/data")["data"]["contacts"][0]
        self.assertEqual((c["stage"], c["nextFollowUp"], len(c["interactions"])), ("Assess", "2030-01-01", 1))
        self.assertEqual(c["notes"], "Written by Claude while the app is open")

    def test_rename_stage_carries_to_contacts(self):
        self.call("/api/add", {"contact": {"name": "A", "stage": "Assess"}})
        conf = self.call("/api/data")["data"]["config"]
        stages = [dict(s, name="Review" if s["name"] == "Assess" else s["name"]) for s in conf["stages"]]
        self.call("/api/config", {"config": {"stages": stages}, "renameStage": ["Assess", "Review"]})
        self.assertEqual(self.call("/api/data")["data"]["contacts"][0]["stage"], "Review")

    def test_refuses_without_token_or_from_another_site(self):
        for kwargs in ({"token": "wrong"}, {"host": "evil.example"}):
            with self.assertRaises(urllib.error.HTTPError) as e:
                self.call("/api/data", **kwargs)
            self.assertEqual(e.exception.code, 403)


if __name__ == "__main__":
    unittest.main()
