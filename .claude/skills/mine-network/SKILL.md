---
name: mine-network
description: Run the network-mining pipeline on the LinkedIn export using profile.json, hand-review titles, estimate company sizes, write opening lines and load the result into the app's data file.
---

# Mine the network

Needs `profile.json` (run `/setup-network` first) and an unzipped LinkedIn export in `export/`. Follow `CLAUDE.md` for the privacy rules. Process every row with the scripts; never sample. Show counts at each step. Stop and show the user at the two points marked below.

1. `python3 scripts/01_enrich.py`, then show the files found, the row counts and the signals. **Stop if anything looks wrong or a signal file is missing that the user expected.** If `use_job_files` is true and saved jobs exist, show a summary and ask whether they count.

2. `python3 scripts/02_classify.py --review`. Read every printed title by hand. The keyword rules are a first pass and always misfire: write corrections to `output/_work/overrides.csv` (columns `contact_id,category,note`; category empty means not relevant). Look for missed local-language titles, words such as "partner" in "partner manager", and people at investors. Add missing title terms to the profile, then rerun.

3. Estimate company sizes for every company that appears in the review. Write `output/_work/company_sizes.tsv` with tab-separated columns `company, est, band, basis, flags`. `band` is one of `in, near_low, near_high, above, below`, using the profile's numbers. `flags` may hold `remote-first`, `hq-elsewhere`, `public`. If you have no basis, leave the company out: it stays "size unknown". Never guess. Everything here is an inference, and the output must say so.

4. If `count_units_inside_large_companies` is true, pick leaders of divisions, regions or country units by hand. Skip functional heads. Write `output/_work/unit_sizes.tsv` with columns `contact_id, unit, est, band, basis`. The unit, not the parent, is held to the band. Unit sizes are low confidence: say so.

5. `python3 scripts/03_score.py`, then `python3 scripts/04_select.py`. Show the counts per list, and check the top of each list by hand. If a list is full of the wrong people, fix the cause in overrides or the profile. **Stop and show the user the summary, including how many connections sit in the target band. If the band is thin, say so plainly: that tells them whether this network can deliver, or whether they need another route.**

6. For everyone in `output/worklist.csv` who needs a line, write `output/_work/lines.json`: `{contact_id: {"why": "...", "en": "...", "nl": "...", ...}}`, one key per language in the profile. Write each by hand. Use one real detail from their title or company. Use only the background and proof points in the profile. Never invent facts about the person or the company. Mention shared history only if the file shows it. Follow `opening_lines` and the goal's `ask`. Investors and board members get one question about what they see, not a request for a call. People in in-talks lists get no line.

7. `python3 scripts/05_check_lines.py` and fix everything it reports.

8. `python3 scripts/06_to_crm.py`. It merges into `data/crm.json` and backs up the old file first. It never touches stages, notes, touchpoints or reminders. Then show where each list stands and tell the user to open the app.

Always state the limits: you only see the export, with no About sections, posts, mutual connections or messages; titles can be years old; company size is inferred for every row and must be checked before writing to anyone.
