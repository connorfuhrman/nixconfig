---
name: restaurant-preference
description: Search restaurants, shortlist with reasons, collect feedback, and update the structured preference store plus durable memory.
---

# Restaurant preference loop

Use this skill for every dining request. The structured store is
`data/restaurants.json` relative to this profile's `HERMES_HOME`.

## Store shape

```json
{
  "version": 1,
  "home_base": "Aliso Viejo, Orange County, CA",
  "preferences": {
    "cuisines_like": ["thai"],
    "cuisines_dislike": ["too-spicy-sichuan"],
    "dietary": [],
    "price": "$$",
    "ambiance": ["quiet-enough-to-talk"],
    "avoids": ["long-waits-with-no-bar"]
  },
  "places": {
    "slug": {
      "name": "Example",
      "area": "Laguna Niguel",
      "cuisine": ["thai"],
      "status": "liked",
      "rating": 4,
      "notes": ["good green curry"],
      "visits": ["2026-08-01"]
    }
  },
  "rounds": [
    {
      "id": "2026-08-24-1",
      "query": "weeknight thai near home",
      "shortlist": ["a", "b", "c"],
      "chosen": "a",
      "feedback": "liked the curry, skip the fried apps next time"
    }
  ]
}
```

`status` is one of: `liked`, `disliked`, `try`, `neutral`.

## Procedure

1. Read `data/restaurants.json`. If missing, create it from the schema above.
2. Read `~/.hermes/shared/trip-context.json` for place, party, dates, budget.
3. If no place is named, use `home_base`.
4. Search the web for currently open options that match stored prefs.
5. Return **three** places. Each item: name, area, why it fits (cite store
   fields), and one caution.
6. After user feedback, patch:
   - `places.<slug>` (status, rating, notes, visits)
   - `preferences.*` when the feedback generalizes
   - `rounds` with the query, shortlist, chosen, and feedback
7. Append a one-line prose update to `memories/MEMORY.md`.
8. Later shortlists **must** drop `disliked` places and prefer `liked`.

## Rules

- Do not invent visits. Only record feedback the user actually gave.
- Two rounds minimum before claiming a stable taste model.
- Never store credentials. Restaurant names and opinions only.
