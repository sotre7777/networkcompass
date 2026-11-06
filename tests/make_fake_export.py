"""Writes a made-up LinkedIn export, for trying the pipeline without real data.

Usage: python3 tests/make_fake_export.py export
Every person and company here is invented.
"""
import csv
import random
import sys
from pathlib import Path

FIRST = ["Alex", "Sam", "Noor", "Mina", "Leo", "Ivy", "Theo", "Rosa", "Kai", "Lena", "Omar", "Priya", "Jonas", "Emi", "Tess"]
LAST = ["Abara", "Berg", "Castell", "Dorn", "Eklund", "Farrow", "Gale", "Holt", "Ito", "Janssen", "Kerr", "Lind", "Moreau", "Novak", "Ortega"]
COMPANIES = ["Northwind Traders", "Acme Robotics", "Bluebird Health", "Harbor Logistics", "Quill Software", "Tidewater Energy",
             "Fable Foods", "Granite Bank", "Lumen Analytics", "Self-employed"]
TITLES = ["CEO", "Chief Operating Officer", "VP Sales", "Head of People", "Director of Engineering", "Account Manager", "Software Engineer",
          "Founder", "Leadership Coach", "Executive Search Consultant", "Partner, Growth Ventures", "Board Member", "Product Owner",
          "Fractional CFO", "Marketing Manager", "Talent Acquisition Partner"]


def write(path, header, rows, preamble=""):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        f.write(preamble)
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "export")
    random.seed(7)
    rows, seen = [], set()
    while len(rows) < 120:
        fn, ln = random.choice(FIRST), random.choice(LAST)
        if (fn, ln) in seen:
            continue
        seen.add((fn, ln))
        slug = f"{fn}-{ln}".lower()
        year = random.randint(2012, 2025)
        rows.append([fn, ln, f"https://www.linkedin.com/in/{slug}", "", random.choice(COMPANIES), random.choice(TITLES),
                     f"{random.randint(10, 28):02d} {random.choice(['Jan', 'Mar', 'Jun', 'Sep', 'Nov'])} {year}"])
    rows.append(["", "", "", "", "", "", "01 Jan 2020"])  # a hidden profile
    write(out / "Connections.csv", ["First Name", "Last Name", "URL", "Email Address", "Company", "Position", "Connected On"], rows,
          'Notes:\n"When exporting your connection data, you may notice that some of the email addresses are missing."\n\n')
    r = rows[0]
    write(out / "Recommendations_Received.csv", ["First Name", "Last Name", "Company", "Job Title", "Text", "Creation Date", "Status"],
          [[r[0], r[1], r[4], r[5], "Great to work with.", "01/01/24", "VISIBLE"]])
    e = rows[1]
    write(out / "Endorsement_Received_Info.csv", ["Endorsement Date", "Skill Name", "Endorser First Name", "Endorser Last Name", "Endorser Public Url", "Endorsement Status"],
          [["2024/01/01 10:00:00 UTC", "Leadership", e[0], e[1], e[2].replace("https://", ""), "ACCEPTED"]])
    write(out / "Company Follows.csv", ["Organization", "Followed On"], [["Quill Software", "2024-01-01"]])
    write(out / "Jobs" / "Saved Jobs.csv", ["Saved Date", "Job Url", "Job Title", "Company Name"], [["1/1/25", "", "Director", "Lumen Analytics"]])
    print(f"Wrote a fake export to {out}/ with {len(rows)} rows.")


if __name__ == "__main__":
    main()
