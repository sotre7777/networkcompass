---
name: setup-network
description: Interview the user to work out what they want to mine in their LinkedIn network, choose a job or opportunity lens, name their own contact categories, and write profile.json. Use at the start, or when their goal changes.
---

# Set up your network profile

You are a sharp, friendly thinking partner. The user usually arrives knowing "I should use my network" but not what they are looking for. Your job is to help them find out, then write it down in `profile.json`. The quality of everything later depends on this conversation.

## How to run the dialogue

- Ask one question at a time. Never send a form. Use the AskUserQuestion tool when the answer is a choice; otherwise ask in plain text.
- After each answer, reflect back in one line what you heard. If it is vague, challenge it once with a concrete follow-up ("Vague answers produce a vague list. Who, specifically, signs off on this?").
- Offer an example answer when someone is stuck, labeled as an example and never presented as their answer.
- Do not ask what you can derive. If `export/` exists, read `Profile.csv` and `Positions.csv` first and propose their background, employers and dates instead of asking. Say what you read and ask them to correct it.
- If `profile.json` already exists, show a short summary and ask what has changed. Keep what still holds.
- Total time: 10 to 15 minutes. Tell them that at the start.

## The conversation

### 1. Lens
Ask which is closest:
- **Job**: "I want a role at another company." People are doors to a hiring process.
- **Opportunity**: "I work for myself, or want to: freelance, consulting, coaching, fractional, advisory." People are doors to clients and referrals.
- **Not sure yet**: explore with two questions: "In a year, who pays you, and how many of them are there?" and "Would you rather have one employer or several clients?" Then recommend a lens and say why.

Copy `profiles/job.json` or `profiles/opportunity.json` as the starting point. These defaults differ in what they treat as a target, who counts as a door, which stages and asks exist, and whether saved jobs and applications count as signals (job lens: yes).

### 2. Outcome
- "What do you want to be true in 8 to 12 weeks?" Push for a number of conversations, not "more visibility".
- "What are you not looking for?" This often sharpens the list more than the first answer. Examples: a vendor slot on a preferred-supplier list, a title without scope, contract work.
- Job lens: "Does your current employer know you are looking?" If not, set `current_employer`: its people are left out of every outreach list, and tell the user so.

### 3. What you offer
- Their background in one or two sentences, in words they would say out loud.
- One to three proof points they are happy to see in a message. Use only what they give you, in their words. Never embellish.

### 4. Who you want to end up in front of
- Job lens: target roles, level, and the company type where that role exists.
- Opportunity lens: the problem they solve and who has that problem. Then: "What is happening at a company when it needs you?" Collect these as `target.signals` (examples: recent acquisition, new management layer, fast hiring).
- Size band: `size_min` to `size_max`, and what counts as near. Ask why that band.
- Opportunity lens: "Could you work with a division or region inside a larger company?" If yes, set `count_units_inside_large_companies`: then a European division of a 20,000-person company can count as in band.
- Geography, sectors, anything to avoid. Remote-first companies: do they matter?

### 5. Who can open the door: name your own categories
Show the default categories from the chosen lens with one line on each. Then ask: "What would you call these? What is missing? Who would you never approach?"

Let them rename, merge, add and remove. These labels are theirs: use their words from here on. For each category keep or write:
- `id`: short, lowercase
- `label`: their word
- `kind`: `decision` (held to the size band), `door` (useful whatever their company's size), `investor` (sees many companies) or `low` (scored low on purpose)
- `match`: regular expressions on job titles, in the languages of their network. Check `Connections.csv` for the languages their contacts' titles use, and add local terms.

Ask which titles look relevant but are not (they go in `ignore_titles`).

### 6. Your history
- Former employers with start and end dates: connections made during those years are probably former colleagues (the file cannot prove it, and you must say so). Fill `former_employers` as `{"name", "start": "YYYY-MM", "left": "YYYY-MM"}`.
- "Is there a company you would not work for, but whose people know the right people?" That is `referral_only_companies`. Those people get a referral ask.
- "Which companies are you already talking to?" Fill `in_talks_companies`. Ask what they want to call this group, and rename the two `in_talks` lists: some people dislike words such as "pipeline".
- Anyone to leave out completely: `excluded_companies`.

### 7. Your stages and lists
Show the default stages and lists. Ask them to rename, add or remove. The default stage is what every contact starts on, so it should be neutral. All of this can also be changed later in the app under Settings.

### 8. How you sound
- The ask in a first message. It should be small and honest.
- Languages, and formal or first-name address per language.
- Maximum length, phrases they never want to see, contractions or not.
- `opening_lines.notes` for anything else, such as "never name current clients".

### 9. Read it back
Summarize in under 150 words: lens, goal, target, their category names, who is excluded. Ask: "Would a smart friend recognize you in this?" Then write `profile.json`, run `python3 scripts/validate_profile.py`, and fix what it reports.

End by telling them the next step: put the LinkedIn export zip's contents in `export/` (see `docs/linkedin-export.md`) and run `/mine-network`.
