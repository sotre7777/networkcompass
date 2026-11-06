# Getting your LinkedIn export

1. On LinkedIn, open Settings & Privacy, then Data privacy, then Get a copy of your data. Menu names change, so search the settings for "copy of your data" if you cannot find it.
2. Choose the larger archive with all files, not just Connections. Recommendations, endorsements, invitations and company follows are what turn a flat list into warm leads. It can take up to a day.
3. Unzip it into `export/` in this repo, so that `export/Connections.csv` exists.

What the archive does not contain: anyone's About section, posts, your mutual connections.

| File | Used for |
|---|---|
| `Connections.csv` | Everyone: name, company, title, connected date |
| `Recommendations_*.csv`, `Endorsement_*.csv` | Direct warmth |
| `Invitations.csv` | Recent contact, only the last few months |
| `Company Follows.csv` | A weak sign of interest |
| `Jobs/Saved Jobs*.csv`, `Jobs/Job Applications*.csv` | Job lens only |
| `Positions.csv`, `Profile.csv` | Read during setup, to propose your background |

To refresh later, replace `export/` with a new archive and run `/mine-network` again. Job changes show up in the app, and your own work is kept.
