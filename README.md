# Network Compass

Find the people in your LinkedIn network who matter for what you want next, then keep those relationships going.

Most advice says "use your network". This repo helps you work out what that means for you. A guided conversation with Claude pins down what you are looking for, the scripts go through every connection in your LinkedIn export, and a small Mac app becomes the place where you work the list: who to contact, what to say, what happened, and when to check in again.

It works through two lenses:

| | Job lens | Opportunity lens |
|---|---|---|
| **For** | Finding your next role | Freelancers, consultants, coaches, fractional and advisory work |
| **A target is** | A role at a company | A client with a problem you solve, or a unit inside a larger company |
| **Doors are** | Hiring managers, recruiters, former colleagues | Decision makers, budget owners, referral sources, other independents |
| **The ask** | Advice, a referral | A conversation, an introduction |
| **Also counts** | Saved jobs and applications | Companies you are already talking to |

Both are starting points. You name your own categories, lists and stages.

## What you get

- **A setup dialogue** (`/setup-network`, 10 to 15 minutes) that helps you decide what to mine, including who you would not approach
- **Every connection scored** 1 to 5 against your own target, with the signals used and the reason, and with every inference labeled
- **Opening lines** in your languages, each written for one person, each checked against your own rules
- **A plain answer on fit**: how much of your network sits in your target at all, and whether you need another route
- **An app to work the list**: your own lists and stages, a Today view, touchpoint logging, check-in reminders, job-change alerts and outreach results. On a Mac it is a native app with notifications, a Dock badge and a menu-bar list. On Windows and Linux it runs in your browser, on your own computer
- **Notes for Claude**: write "former colleague, informal, move to Warm network" on a contact in the app, run `/process-notes`, and Claude applies it and rewrites the opening line

## Quick start

**New to this? Follow [docs/GETTING-STARTED.md](docs/GETTING-STARTED.md).** It explains every step and needs no coding.

The short version needs [Claude Code](https://claude.com/claude-code). On a Mac with macOS 14 or newer:

```bash
git clone <this repo> network-compass
cd network-compass
zsh setup.sh
claude
```

On Windows, install Git and Python first, then replace `zsh setup.sh` with `powershell -ExecutionPolicy Bypass -File setup.ps1`.

Then in Claude Code:

1. Run `/setup-network` and have the conversation. It writes `profile.json`.
2. Unzip your LinkedIn archive into `export/`. See [docs/linkedin-export.md](docs/linkedin-export.md).
3. Run `/mine-network`. Plan about an hour: Claude reads the titles by hand and writes the lines.
4. Open **Network Compass**: from `~/Applications` on a Mac, from the desktop shortcut on Windows. Elsewhere, run `python3 webapp/server.py`.
5. Work the list. Add what only you know as Notes for Claude, then run `/process-notes`.

To try it without real data: `python3 tests/make_fake_export.py export`.

## How your data is handled

- Everything stays in your clone: `export/`, `output/`, `data/` and `profile.json` are git-ignored. Neither app makes network calls; the browser version only listens on your own computer.
- **Claude Code does send what it reads to Anthropic's API** to do its work. That includes the names and titles it reviews. Check that this fits your situation before you start.
- Your export holds other people's names and some email addresses. Keep it private, do not publish the output, and delete the zip when you are done.

## Limits

- It only sees the export: no About sections, posts, mutual connections or messages.
- Titles can be years old. Company size is inferred for every row, so check it before you write to anyone.
- Name matching for recommendations can be wrong when two people share a name; those are flagged.
- The list misses people. Add them in the app with ⌘N, LinkedIn connection or not.
- Reminders reach you as notifications only in the Mac app. In the browser version they show inside the app. There is no phone version.

## In this repo

| Path | What it is |
|---|---|
| `.claude/skills/` | The three commands: the setup dialogue, the analysis, note processing |
| `profiles/` | Starting points for each lens |
| `scripts/` | The pipeline, numbered in run order, plus `crm.py` for changing the data file |
| `app/` | The native Mac app and its build script |
| `webapp/` | The browser version, for Windows, Mac and Linux |
| `docs/` | Step-by-step instructions, the LinkedIn export, the data format, how scoring works |
| `tests/` | A fake export and end-to-end tests (`python3 -m unittest discover tests`) |

## Credits

Built on [mine_your_linkedin_network](https://github.com/franzi-br/mine_your_linkedin_network) by Franziska Bruno Rivera, a prompt kit for finding advice conversations in a job search. The core method comes from there: show the headers before scoring, process every row, separate data from inference, and add what only you know in a second pass.

MIT licensed. See [LICENSE](LICENSE).
