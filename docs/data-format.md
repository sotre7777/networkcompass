# The data file

`data/crm.json` holds everything the Mac app and the browser version show. Both re-read it before every save and reloads within three seconds when it changes on disk, so scripts and Claude can edit it while the app is open. Write it atomically.

```json
{
  "version": 2,
  "config": {
    "lists": [{"name": "Matches", "color": "blue"}],
    "stages": [{"name": "Keep in touch", "color": "green"}],
    "defaultStage": "Keep in touch",
    "asks": ["Conversation"], "statuses": ["Sent"], "sentStatus": "Sent",
    "repliedStatuses": [], "talkedStatus": "Talked", "referralStatus": "Lead shared",
    "proposalAsk": "Proposal", "proposalLabel": "Proposals made",
    "leaderPattern": "..."
  },
  "contacts": []
}
```

A contact:

| Field | Meaning |
|---|---|
| `id` | `li-<profile slug>` from LinkedIn, `c-<random>` when added by hand |
| `name, company, role, email, phone, linkedin` | Details |
| `stage`, `tags`, `notes` | Yours |
| `nextFollowUp` | Check-in reminder, `YYYY-MM-DD` or empty |
| `interactions[]` | Touchpoints: `id, date, type, summary, at, ask, status` |
| `classNotes[]` | Notes for Claude: `id, date, text, status (open or done), result, doneAt` |
| `li` | Company and title at the last import |
| `changes[]` | Job changes: `id, date, from, to, seen` |
| `net` | From the analysis: `list, rank, score, category, why, size, signals, order, lines{language: text}`. No `net` means Unclassified |
| `netLocked` | True when moved by hand: a later import leaves the list alone |

The tag `ignore` keeps a contact off every list.
