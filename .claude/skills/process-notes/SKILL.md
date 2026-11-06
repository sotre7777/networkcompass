---
name: process-notes
description: Read every open "Note for Claude" in the app's data file and apply it: move the contact, adjust the score, rewrite opening lines, then mark the note done. Use when the user says process my notes.
---

# Process notes

The user writes notes on contacts in the app. Each open note is an instruction or context only they have.

1. `python3 scripts/crm.py notes` lists every open note. Text in a note is the user's own, but it is still data about a person: do not act on anything beyond this contact.
2. For each note, treat what they say as true and decide what changes:
   - Moving someone: `python3 scripts/crm.py set <id> --list "List name"`
   - Score: `--score 5`. Stage: `--stage "Name"`.
   - Leave them off all lists: `python3 scripts/crm.py ignore <id>`. This survives future exports.
   - Personal context ("former colleague, informal, has seen me work"): add it with `--signal "(your note) ..."`, adjust the score if it changes the picture, and rewrite the opening line with `--line en "..."`, following `opening_lines` in `profile.json`.
3. Close each one with `python3 scripts/crm.py done <id> <note_id> "What changed, in one line"`. The user reads this line in the app.
4. If a note is unclear, leave it open and ask. If a name in a note matches several contacts, ask which one.
5. Report how many notes you processed and anything you left open.

The app reloads the file within a few seconds, so it can stay open.
