# How scoring works

Each person gets a base score from their category's `kind` and the size band of their company. Everything scoring below 4 stays out of the main lists.

| Kind | In band | Near band | Above | Below or unknown |
|---|---|---|---|---|
| `decision` | 5 | 4 | 3 | 2 |
| `door` (useful at any company size) | 4 | 4 | 4 | 4 |
| `investor` | 4 | 4 | 4 | 4 |
| `low` (generalist recruiters, for example) | 2 | 2 | 2 | 2 |
| No category, senior, likely former colleague | 4 | 3 | 2 | 2 |

Lifts:
- A direct signal (recommendation, endorsement, recent invitation) adds 1, up to 5.
- The former-employer proxy adds 1 only from 3 to 4. It covers too many people to tell who is warm, so it cannot make a 5 by itself.
- A lift never makes an irrelevant title relevant.

With `count_units_inside_large_companies`, a leader of a division, region or country is scored on the unit's size. Companies in `referral_only_companies` go to their own list and get a referral ask. `in_talks_companies` are split into leaders and others, without opening lines.

The rules live in `scripts/03_score.py` and `scripts/04_select.py`. Change them if your situation differs: that is why they are short.
